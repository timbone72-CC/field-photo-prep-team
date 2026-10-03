package com.inandout.fieldphotoprep.team.internal;

import android.content.Context;

import androidx.room.Database;
import androidx.room.Room;
import androidx.room.RoomDatabase;

@Database(entities = {CachedWorkOrder.class}, version = 1, exportSchema = true)
abstract class TeamDatabase extends RoomDatabase {
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
                current = Room.databaseBuilder(
                                context.getApplicationContext(),
                                TeamDatabase.class,
                                "field-photo-prep-team.db")
                        .build();
                instance = current;
            }
        }
        return current;
    }
}
