package com.inandout.fieldphotoprep.team.internal;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;
import androidx.room.Transaction;

import java.util.List;

@Dao
abstract class CachedWorkOrderDao {
    @Query("SELECT * FROM cached_work_orders "
            + "WHERE cache_owner_user_id = :cacheOwnerUserId AND organization_id = :organizationId "
            + "ORDER BY due_date ASC, wo_number ASC")
    abstract List<CachedWorkOrder> listForOwner(String cacheOwnerUserId, String organizationId);

    @Query("DELETE FROM cached_work_orders "
            + "WHERE cache_owner_user_id = :cacheOwnerUserId AND organization_id = :organizationId")
    abstract void deleteForOwner(String cacheOwnerUserId, String organizationId);

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    abstract void insertAll(List<CachedWorkOrder> rows);

    @Transaction
    void replaceForOwner(String cacheOwnerUserId, String organizationId, List<CachedWorkOrder> rows) {
        deleteForOwner(cacheOwnerUserId, organizationId);
        if (!rows.isEmpty()) {
            insertAll(rows);
        }
    }
}
