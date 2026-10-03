package com.inandout.fieldphotoprep.team.internal;

import java.util.ArrayList;
import java.util.List;

final class RoomAssignmentStore implements AssignmentStore {
    private final CachedWorkOrderDao dao;

    RoomAssignmentStore(CachedWorkOrderDao dao) {
        this.dao = dao;
    }

    @Override
    public void replace(
            SupabaseApi.AuthSession session,
            List<SupabaseApi.WorkOrder> workOrders,
            long lastSuccessfulSyncEpochMs) {
        List<CachedWorkOrder> rows = new ArrayList<>();
        for (SupabaseApi.WorkOrder workOrder : workOrders) {
            rows.add(new CachedWorkOrder(
                    session.userId,
                    session.organizationId,
                    workOrder.id,
                    workOrder.currentRunId,
                    workOrder.currentRunSequence,
                    workOrder.assignedUserId,
                    workOrder.woNumber,
                    workOrder.propertyAddress,
                    workOrder.workType,
                    workOrder.instructions,
                    "[]",
                    workOrder.dueDate,
                    "{}",
                    workOrder.fieldStatus,
                    workOrder.assignmentReceivedAt,
                    workOrder.startedAt,
                    workOrder.fieldCompletedAt,
                    workOrder.pendingAssigneeUserId,
                    workOrder.reassignmentRequestedAt,
                    workOrder.serverUpdatedAt,
                    lastSuccessfulSyncEpochMs));
        }
        dao.replaceForOwner(session.userId, session.organizationId, rows);
    }

    @Override
    public List<SupabaseApi.WorkOrder> load(SupabaseApi.AuthSession session) {
        List<CachedWorkOrder> rows = dao.listForOwner(session.userId, session.organizationId);
        List<SupabaseApi.WorkOrder> result = new ArrayList<>();
        for (CachedWorkOrder row : rows) {
            result.add(new SupabaseApi.WorkOrder(
                    row.workOrderId,
                    row.organizationId,
                    row.runId,
                    row.runSequence,
                    row.woNumber,
                    row.propertyAddress,
                    row.workType,
                    row.instructions,
                    row.dueDate,
                    row.fieldStatus,
                    row.assignedUserId,
                    row.pendingAssigneeUserId,
                    row.reassignmentRequestedAt,
                    row.assignmentReceivedAt,
                    row.startedAt,
                    row.fieldCompletedAt,
                    row.serverUpdatedAt));
        }
        return result;
    }
}
