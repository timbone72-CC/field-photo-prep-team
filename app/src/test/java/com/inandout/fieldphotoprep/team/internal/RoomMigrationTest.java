package com.inandout.fieldphotoprep.team.internal;

import static org.junit.Assert.*;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;

import androidx.room.Room;

import org.json.*;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

import java.nio.charset.StandardCharsets;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class RoomMigrationTest {
    @Test
    public void realV1SchemaUpgradesPreservingTwoOwnersAndRestartedQueue() throws Exception {
        Context context = RuntimeEnvironment.getApplication();
        String name = "migration-test.db";
        context.deleteDatabase(name);
        java.io.InputStream stream =
                getClass()
                        .getResourceAsStream(
                                "/com.inandout.fieldphotoprep.team.internal.TeamDatabase/1.json");
        assertNotNull(stream);
        JSONObject schema =
                new JSONObject(new String(stream.readAllBytes(), StandardCharsets.UTF_8))
                        .getJSONObject("database");
        try (SQLiteDatabase old = context.openOrCreateDatabase(name, Context.MODE_PRIVATE, null)) {
            JSONArray entities = schema.getJSONArray("entities");
            for (int i = 0; i < entities.length(); i++) {
                JSONObject entity = entities.getJSONObject(i);
                old.execSQL(
                        entity.getString("createSql")
                                .replace("${TABLE_NAME}", entity.getString("tableName")));
                JSONArray indices = entity.getJSONArray("indices");
                for (int j = 0; j < indices.length(); j++)
                    old.execSQL(
                            indices.getJSONObject(j)
                                    .getString("createSql")
                                    .replace("${TABLE_NAME}", entity.getString("tableName")));
            }
            JSONArray setup = schema.getJSONArray("setupQueries");
            for (int i = 0; i < setup.length(); i++) old.execSQL(setup.getString(i));
            for (String user : new String[] {"a", "b"}) {
                android.content.ContentValues row = new android.content.ContentValues();
                JSONArray fields = entities.getJSONObject(0).getJSONArray("fields");
                for (int i = 0; i < fields.length(); i++) {
                    JSONObject f = fields.getJSONObject(i);
                    if ("INTEGER".equals(f.getString("affinity")))
                        row.put(f.getString("columnName"), 1);
                    else row.put(f.getString("columnName"), "");
                }
                row.put("cache_owner_user_id", user);
                row.put("organization_id", "org");
                row.put("work_order_id", "1");
                row.put("run_id", "run-1");
                row.put("assigned_user_id", user);
                row.put("field_status", "ASSIGNED");
                row.put("wo_number", "WO-1");
                old.insertOrThrow("cached_work_orders", null, row);
            }
            old.setVersion(1);
        }
        TeamDatabase upgraded =
                Room.databaseBuilder(context, TeamDatabase.class, name)
                        .addMigrations(TeamDatabase.MIGRATION_1_2)
                        .allowMainThreadQueries()
                        .build();
        assertEquals(1, upgraded.cachedWorkOrderDao().listForOwner("a", "org").size());
        assertEquals(1, upgraded.cachedWorkOrderDao().listForOwner("b", "org").size());
        assertEquals(
                "",
                upgraded.cachedWorkOrderDao().find("a", "org", "1", "run-1").assignmentInstanceId);
        assertThrows(
                IllegalStateException.class,
                () ->
                        upgraded.cachedWorkOrderDao()
                                .createAction(
                                        OfflineActionTest.session("a", "org"),
                                        "1",
                                        "run-1",
                                        "START",
                                        "2026-10-03T12:00:00Z"));
        new RoomAssignmentStore(upgraded.cachedWorkOrderDao())
                .replace(
                        OfflineActionTest.session("a", "org"),
                        java.util.List.of(OfflineActionTest.wo("1", "instance")),
                        1);
        FieldAction action =
                upgraded.cachedWorkOrderDao()
                        .createAction(
                                OfflineActionTest.session("a", "org"),
                                "1",
                                "run-1",
                                "START",
                                "2026-10-03T12:00:00Z");
        upgraded.close();
        TeamDatabase reopened =
                Room.databaseBuilder(context, TeamDatabase.class, name)
                        .addMigrations(TeamDatabase.MIGRATION_1_2)
                        .allowMainThreadQueries()
                        .build();
        assertEquals(
                action.eventTime, reopened.cachedWorkOrderDao().action(action.actionId).eventTime);
        assertEquals("PENDING", reopened.cachedWorkOrderDao().action(action.actionId).state);
        assertEquals(1, reopened.cachedWorkOrderDao().listForOwner("b", "org").size());
        reopened.close();
        context.deleteDatabase(name);
    }
}
