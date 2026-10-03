package com.inandout.fieldphotoprep.team.internal;

import android.content.Context;

import androidx.room.Database;
import androidx.room.Room;
import androidx.room.RoomDatabase;

@Database(
        entities = {CachedWorkOrder.class, FieldAction.class},
        version = 2,
        exportSchema = true)
abstract class TeamDatabase extends RoomDatabase {
    static final androidx.room.migration.Migration MIGRATION_1_2 =
            new androidx.room.migration.Migration(1, 2) {
                @Override
                public void migrate(androidx.sqlite.db.SupportSQLiteDatabase db) {
                    db.execSQL(
                            "ALTER TABLE cached_work_orders ADD COLUMN assignment_instance_id TEXT"
                                + " NOT NULL DEFAULT ''");
                    db.execSQL(
                            "ALTER TABLE cached_work_orders ADD COLUMN conflict_reason TEXT NOT"
                                + " NULL DEFAULT ''");
                    db.execSQL(
                            "CREATE TABLE IF NOT EXISTS field_actions (actionId TEXT NOT NULL"
                                + " PRIMARY KEY,ownerId TEXT NOT NULL,organizationId TEXT NOT"
                                + " NULL,workOrderId TEXT NOT NULL,runId TEXT NOT"
                                + " NULL,assignmentInstanceId TEXT NOT NULL,kind TEXT NOT"
                                + " NULL,eventTime TEXT NOT NULL,createdAt INTEGER NOT"
                                + " NULL,sequence INTEGER NOT NULL,state TEXT NOT NULL,attempts"
                                + " INTEGER NOT NULL,retryNotBefore INTEGER NOT NULL,reason TEXT"
                                + " NOT NULL,claimId TEXT NOT NULL,claimGeneration INTEGER NOT"
                                + " NULL,canonicalStatus TEXT NOT NULL,canonicalStartedAt TEXT NOT"
                                + " NULL,canonicalCompletedAt TEXT NOT NULL,serverUpdatedAt TEXT"
                                + " NOT NULL,acceptedAt TEXT NOT NULL)");
                    db.execSQL(
                            "CREATE UNIQUE INDEX IF NOT EXISTS"
                                + " index_field_actions_ownerId_organizationId_workOrderId_runId_assignmentInstanceId_kind"
                                + " ON field_actions(ownerId,organizationId,workOrderId,runId,assignmentInstanceId,kind)");
                    db.execSQL(
                            "CREATE INDEX IF NOT EXISTS"
                                + " index_field_actions_ownerId_organizationId_sequence ON"
                                + " field_actions(ownerId,organizationId,sequence)");
                }
            };
    private static volatile TeamDatabase instance;

    abstract CachedWorkOrderDao cachedWorkOrderDao();

    static TeamDatabase getInstance(Context context) {
        TeamDatabase current = instance;
        if (current != null) {
            return current;
        }
        synchronized (TeamDatabase.class) {
            current = instance;
            if (current == null) {
                current =
                        Room.databaseBuilder(
                                        context.getApplicationContext(),
                                        TeamDatabase.class,
                                        "field-photo-prep-team.db")
                                .addMigrations(MIGRATION_1_2)
                                .build();
                instance = current;
            }
        }
        return current;
    }
}
