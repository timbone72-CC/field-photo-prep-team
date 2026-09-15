package com.inandout.fieldphotoprep.team.internal;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

public final class AssignmentRepositoryTest {
    private static final String USER = "user-a";
    private static final String ORG = "org-a";

    @Test
    public void receiptIsNotAcknowledgedWhenDurableSaveFails() {
        FakeRemote remote = new FakeRemote(Collections.singletonList(workOrder("", USER, ORG)));
        FakeStore store = new FakeStore();
        store.failReplace = true;
        AssignmentRepository repository = new AssignmentRepository(remote, store);

        assertThrows(IllegalStateException.class, () -> repository.refresh(session(USER, ORG)));

        assertEquals(0, remote.acknowledgementCount);
        assertEquals(1, store.replaceCount);
    }

    @Test
    public void receiptIsAcknowledgedOnlyAfterFirstSaveThenConfirmedSnapshotIsStored() throws Exception {
        FakeRemote remote = new FakeRemote(
                Collections.singletonList(workOrder("", USER, ORG)),
                Collections.singletonList(workOrder("2026-09-15T12:00:00Z", USER, ORG)));
        FakeStore store = new FakeStore();
        AssignmentRepository repository = new AssignmentRepository(remote, store);

        List<SupabaseApi.WorkOrder> result = repository.refresh(session(USER, ORG));

        assertEquals(1, remote.acknowledgementCount);
        assertTrue(remote.ackObservedAfterStore);
        assertEquals(2, store.replaceCount);
        assertEquals("2026-09-15T12:00:00Z", result.get(0).assignmentReceivedAt);
    }

    @Test
    public void contractorCannotCacheForeignAssignmentEvenIfRemoteReturnsIt() {
        FakeRemote remote = new FakeRemote(Collections.singletonList(workOrder("", "user-b", ORG)));
        FakeStore store = new FakeStore();
        AssignmentRepository repository = new AssignmentRepository(remote, store);

        assertThrows(IllegalStateException.class, () -> repository.refresh(session(USER, ORG)));

        assertEquals(0, store.replaceCount);
        assertEquals(0, remote.acknowledgementCount);
    }

    private static SupabaseApi.AuthSession session(String userId, String organizationId) {
        return new SupabaseApi.AuthSession(
                "access",
                "refresh",
                userId,
                "contractor@example.invalid",
                "CONTRACTOR",
                organizationId,
                0L);
    }

    private static SupabaseApi.WorkOrder workOrder(
            String receipt,
            String assignedUserId,
            String organizationId) {
        return new SupabaseApi.WorkOrder(
                "wo-1",
                organizationId,
                "run-1",
                1,
                "WO-1",
                "100 Test Rd",
                "Inspection",
                "",
                "2026-09-16",
                "ASSIGNED",
                assignedUserId,
                "",
                "",
                receipt,
                "",
                "",
                "2026-09-15T12:00:00Z");
    }

    private static final class FakeRemote implements AssignmentRepository.Remote {
        private final List<List<SupabaseApi.WorkOrder>> responses;
        private int fetchIndex;
        int acknowledgementCount;
        boolean ackObservedAfterStore;
        FakeStore observedStore;

        @SafeVarargs
        FakeRemote(List<SupabaseApi.WorkOrder>... responses) {
            this.responses = Arrays.asList(responses);
        }

        @Override
        public List<SupabaseApi.WorkOrder> fetchWorkOrders(String accessToken) {
            int index = Math.min(fetchIndex, responses.size() - 1);
            fetchIndex++;
            return new ArrayList<>(responses.get(index));
        }

        @Override
        public void acknowledgeAssignmentReceived(String accessToken, String workOrderId) {
            acknowledgementCount++;
            if (observedStore != null) {
                ackObservedAfterStore = observedStore.replaceCount > 0;
            } else {
                ackObservedAfterStore = true;
            }
        }
    }

    private static final class FakeStore implements AssignmentStore {
        int replaceCount;
        boolean failReplace;
        List<SupabaseApi.WorkOrder> rows = new ArrayList<>();

        @Override
        public void replace(
                SupabaseApi.AuthSession session,
                List<SupabaseApi.WorkOrder> workOrders,
                long lastSuccessfulSyncEpochMs) {
            replaceCount++;
            if (failReplace) {
                throw new IllegalStateException("disk write failed");
            }
            rows = new ArrayList<>(workOrders);
        }

        @Override
        public List<SupabaseApi.WorkOrder> load(SupabaseApi.AuthSession session) {
            return new ArrayList<>(rows);
        }
    }
}
