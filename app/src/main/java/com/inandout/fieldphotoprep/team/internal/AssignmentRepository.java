package com.inandout.fieldphotoprep.team.internal;

import java.util.List;

final class AssignmentRepository {
    interface Remote {
        List<SupabaseApi.WorkOrder> fetchWorkOrders(String accessToken) throws Exception;

        void acknowledgeAssignmentReceived(String accessToken, String workOrderId) throws Exception;
    }

    private final Remote remote;
    private final AssignmentStore store;

    AssignmentRepository(Remote remote, AssignmentStore store) {
        this.remote = remote;
        this.store = store;
    }

    List<SupabaseApi.WorkOrder> refresh(SupabaseApi.AuthSession session) throws Exception {
        List<SupabaseApi.WorkOrder> downloaded = remote.fetchWorkOrders(session.accessToken);
        validateServerRows(session, downloaded);

        long syncTime = System.currentTimeMillis();
        store.replace(session, downloaded, syncTime);

        boolean receiptChanged = false;
        if ("CONTRACTOR".equals(session.role)) {
            for (SupabaseApi.WorkOrder workOrder : downloaded) {
                if (session.userId.equals(workOrder.assignedUserId)
                        && !"CANCELLED".equals(workOrder.fieldStatus)
                        && workOrder.assignmentReceivedAt.isEmpty()) {
                    remote.acknowledgeAssignmentReceived(session.accessToken, workOrder.id);
                    receiptChanged = true;
                }
            }
        }

        if (receiptChanged) {
            List<SupabaseApi.WorkOrder> confirmed = remote.fetchWorkOrders(session.accessToken);
            validateServerRows(session, confirmed);
            store.replace(session, confirmed, System.currentTimeMillis());
        }

        return store.load(session);
    }

    List<SupabaseApi.WorkOrder> loadCached(SupabaseApi.AuthSession session) {
        return store.load(session);
    }

    private void validateServerRows(
            SupabaseApi.AuthSession session,
            List<SupabaseApi.WorkOrder> workOrders) {
        for (SupabaseApi.WorkOrder workOrder : workOrders) {
            if (!session.organizationId.equals(workOrder.organizationId)) {
                throw new IllegalStateException("Server returned a work order from another organization.");
            }
            if (workOrder.currentRunId.isEmpty() || workOrder.currentRunSequence < 1) {
                throw new IllegalStateException("Server returned a work order without a valid current run.");
            }
            if ("CONTRACTOR".equals(session.role)
                    && !session.userId.equals(workOrder.assignedUserId)) {
                throw new IllegalStateException("Server returned a work order assigned to another contractor.");
            }
        }
    }
}
