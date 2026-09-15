package com.inandout.fieldphotoprep.team.internal;

import java.util.List;

interface AssignmentStore {
    void replace(
            SupabaseApi.AuthSession session,
            List<SupabaseApi.WorkOrder> workOrders,
            long lastSuccessfulSyncEpochMs);

    List<SupabaseApi.WorkOrder> load(SupabaseApi.AuthSession session);
}
