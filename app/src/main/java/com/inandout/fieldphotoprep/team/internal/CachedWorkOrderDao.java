package com.inandout.fieldphotoprep.team.internal;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;
import androidx.room.Transaction;

import java.util.List;

@Dao
abstract class CachedWorkOrderDao {
    @Query(
            "SELECT * FROM cached_work_orders WHERE cache_owner_user_id = :cacheOwnerUserId AND"
                + " organization_id = :organizationId ORDER BY due_date ASC, wo_number ASC")
    abstract List<CachedWorkOrder> listForOwner(String cacheOwnerUserId, String organizationId);

    @Query(
            "DELETE FROM cached_work_orders WHERE cache_owner_user_id = :cacheOwnerUserId AND"
                + " organization_id = :organizationId")
    abstract void deleteForOwner(String cacheOwnerUserId, String organizationId);

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    abstract void insertAll(List<CachedWorkOrder> rows);

    @Query(
            "SELECT * FROM cached_work_orders WHERE cache_owner_user_id=:owner AND"
                + " organization_id=:org AND work_order_id=:wo AND run_id=:run")
    abstract CachedWorkOrder find(String owner, String org, String wo, String run);

    @Query(
            "DELETE FROM cached_work_orders WHERE cache_owner_user_id=:owner AND"
                + " organization_id=:org AND work_order_id=:wo AND run_id=:run")
    abstract void delete(String owner, String org, String wo, String run);

    @Query(
            "SELECT * FROM field_actions WHERE ownerId=:owner AND organizationId=:org ORDER BY"
                + " sequence")
    abstract List<FieldAction> actions(String owner, String org);

    @Query("SELECT * FROM field_actions WHERE actionId=:id")
    abstract FieldAction action(String id);

    @Query("SELECT coalesce(max(sequence),0)+1 FROM field_actions")
    abstract long nextSequence();

    @Insert(onConflict = OnConflictStrategy.ABORT)
    abstract void insertAction(FieldAction action);

    @androidx.room.Update
    abstract void updateAction(FieldAction action);

    @Query(
            "UPDATE field_actions SET state='PENDING',claimId='',reason='INTERRUPTED' WHERE"
                + " ownerId=:owner AND organizationId=:org AND state='SYNCING'")
    abstract void recoverClaims(String owner, String org);

    @Query(
            "UPDATE cached_work_orders SET conflict_reason=:reason WHERE cache_owner_user_id=:owner"
                + " AND organization_id=:org AND work_order_id=:wo AND run_id=:run")
    abstract void conflictCache(String owner, String org, String wo, String run, String reason);

    @Query(
            "UPDATE cached_work_orders SET"
                + " field_status=:status,started_at=:started,field_completed_at=:completed,server_updated_at=:updated"
                + " WHERE cache_owner_user_id=:owner AND organization_id=:org AND work_order_id=:wo"
                + " AND run_id=:run AND assignment_instance_id=:instance")
    abstract void canonicalCache(
            String owner,
            String org,
            String wo,
            String run,
            String instance,
            String status,
            String started,
            String completed,
            String updated);

    boolean hasEvidence(CachedWorkOrder row, List<FieldAction> actions) {
        if (!row.startedAt.isEmpty()) return true;
        return hasLocalActions(row, actions);
    }

    private boolean hasLocalActions(CachedWorkOrder row, List<FieldAction> actions) {
        for (FieldAction a : actions)
            if (a.workOrderId.equals(row.workOrderId) && a.runId.equals(row.runId)) return true;
        return false;
    }

    @Transaction
    void replaceForOwner(String owner, String org, List<CachedWorkOrder> downloaded) {
        List<FieldAction> actions = actions(owner, org);
        List<CachedWorkOrder> existing = listForOwner(owner, org);
        java.util.Set<String> protectedWos = new java.util.HashSet<>();
        for (CachedWorkOrder old : existing) {
            CachedWorkOrder next = null;
            for (CachedWorkOrder row : downloaded)
                if (row.workOrderId.equals(old.workOrderId)) {
                    next = row;
                    break;
                }
            boolean evidence = hasEvidence(old, actions);
            if (next == null
                    || !next.runId.equals(old.runId)
                    || (evidence
                            && (!old.assignmentInstanceId.isEmpty() || hasLocalActions(old, actions))
                            && !next.assignmentInstanceId.equals(old.assignmentInstanceId))
                    || (evidence && "CANCELLED".equals(next.fieldStatus))) {
                if (evidence) {
                    markRunConflict(
                            owner, org, old.workOrderId, old.runId, "ASSIGNMENT_UNAVAILABLE");
                    protectedWos.add(old.workOrderId);
                } else delete(owner, org, old.workOrderId, old.runId);
            } else if (!old.conflictReason.isEmpty()) {
                protectedWos.add(old.workOrderId);
            } else if (evidence && isOlder(next.serverUpdatedAt, old.serverUpdatedAt)) {
                protectedWos.add(old.workOrderId);
            } else if (evidence && statusRank(next.fieldStatus) < statusRank(old.fieldStatus)) {
                markRunConflict(owner, org, old.workOrderId, old.runId, "STATE_CHANGED");
                protectedWos.add(old.workOrderId);
            }
        }
        for (CachedWorkOrder row : downloaded)
            if (!protectedWos.contains(row.workOrderId))
                insertAll(java.util.Collections.singletonList(row));
    }

    static boolean isOlder(String incoming, String current) {
        try {
            return java.time.Instant.parse(incoming).isBefore(java.time.Instant.parse(current));
        } catch (Exception e) {
            return !current.isEmpty();
        }
    }

    static int statusRank(String status) {
        return "FIELD_COMPLETE".equals(status) ? 2 : "IN_PROGRESS".equals(status) ? 1 : 0;
    }

    @Transaction
    void markRunConflict(String owner, String org, String wo, String run, String reason) {
        conflictCache(owner, org, wo, run, reason);
        for (FieldAction a : actions(owner, org))
            if (a.workOrderId.equals(wo) && a.runId.equals(run) && !"ACCEPTED".equals(a.state)) {
                a.state = "CONFLICT";
                a.reason = reason;
                a.claimId = "";
                updateAction(a);
            }
    }

    @Transaction
    FieldAction createAction(
            SupabaseApi.AuthSession session, String wo, String run, String kind, String eventTime) {
        CachedWorkOrder row = find(session.userId, session.organizationId, wo, run);
        if (row == null
                || !"CONTRACTOR".equals(session.role)
                || !row.assignedUserId.equals(session.userId)
                || row.assignmentInstanceId.isEmpty()
                || !row.conflictReason.isEmpty())
            throw new IllegalStateException(
                    "Refresh Assignments online before starting this work, or contact Admin if it"
                        + " needs review.");
        java.time.Instant event = java.time.Instant.parse(eventTime);
        FieldAction start = null;
        for (FieldAction a : actions(session.userId, session.organizationId))
            if (a.workOrderId.equals(wo) && a.runId.equals(run)) {
                if ("CONFLICT".equals(a.state) || a.reason.startsWith("PROTOCOL"))
                    throw new IllegalStateException("Saved progress needs review. Contact Admin.");
                if (a.assignmentInstanceId.equals(row.assignmentInstanceId) && a.kind.equals(kind))
                    return a;
                if (a.kind.equals("START")) start = a;
            }
        if ("START".equals(kind)) {
            if (!"ASSIGNED".equals(row.fieldStatus))
                throw new IllegalStateException("This work cannot be started.");
        } else if ("COMPLETE".equals(kind)) {
            if (!"IN_PROGRESS".equals(row.fieldStatus) && start == null)
                throw new IllegalStateException("Start Work first.");
            String started = !row.startedAt.isEmpty() ? row.startedAt : start.eventTime;
            if (event.isBefore(java.time.Instant.parse(started)))
                throw new IllegalStateException(
                        "Phone time is earlier than the saved start. Correct the phone time before"
                            + " finishing.");
        } else throw new IllegalArgumentException("Unknown action");
        FieldAction a =
                new FieldAction(
                        java.util.UUID.randomUUID().toString(),
                        session.userId,
                        session.organizationId,
                        wo,
                        run,
                        row.assignmentInstanceId,
                        kind,
                        eventTime,
                        System.currentTimeMillis(),
                        nextSequence());
        insertAction(a);
        return a;
    }

    @Transaction
    FieldAction claim(String id, String claim, long generation) {
        FieldAction a = action(id);
        if (a == null || !"PENDING".equals(a.state)) return null;
        a.state = "SYNCING";
        a.claimId = claim;
        a.claimGeneration = generation;
        a.attempts++;
        updateAction(a);
        return a;
    }

    @Transaction
    void accept(String id, String claim, long generation, FieldActionResult result) {
        FieldAction a = action(id);
        if (a == null
                || !a.claimId.equals(claim)
                || a.claimGeneration != generation
                || !"SYNCING".equals(a.state)) return;
        if (result.conflict) {
            markRunConflict(a.ownerId, a.organizationId, a.workOrderId, a.runId, result.reason);
            return;
        }
        a.state = "ACCEPTED";
        a.claimId = "";
        a.reason = "";
        a.canonicalStatus = result.status;
        a.canonicalStartedAt = result.startedAt;
        a.canonicalCompletedAt = result.completedAt;
        a.serverUpdatedAt = result.updatedAt;
        a.acceptedAt = result.acceptedAt;
        updateAction(a);
        canonicalCache(
                a.ownerId,
                a.organizationId,
                a.workOrderId,
                a.runId,
                a.assignmentInstanceId,
                result.status,
                result.startedAt,
                result.completedAt,
                result.updatedAt);
    }

    void release(String id, String claim, String reason) {
        release(id, claim, reason, 0);
    }

    @Transaction
    void release(String id, String claim, String reason, long retryNotBefore) {
        FieldAction a = action(id);
        if (a != null && a.claimId.equals(claim) && "SYNCING".equals(a.state)) {
            a.state = "PENDING";
            a.claimId = "";
            a.reason = reason;
            a.retryNotBefore = retryNotBefore;
            updateAction(a);
        }
    }
}
