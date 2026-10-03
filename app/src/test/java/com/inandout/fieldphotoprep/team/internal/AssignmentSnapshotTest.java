package com.inandout.fieldphotoprep.team.internal;

import static org.junit.Assert.*;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class AssignmentSnapshotTest {
    @Test
    public void partialOrUnprovenResponseCannotBecomeRemovalAuthority() throws Exception {
        SupabaseApi.validateCompleteSnapshot("[{},{},{}]", "0-2/3");
        SupabaseApi.validateCompleteSnapshot("[]", "*/0");
        assertThrows(
                java.io.IOException.class,
                () -> SupabaseApi.validateCompleteSnapshot("[{},{},{}]", "0-2/10"));
        assertThrows(
                java.io.IOException.class, () -> SupabaseApi.validateCompleteSnapshot("[]", null));
        assertThrows(
                java.io.IOException.class,
                () -> SupabaseApi.validateCompleteSnapshot("[{}]", "1-1/1"));
        assertThrows(
                java.io.IOException.class,
                () -> SupabaseApi.validateCompleteSnapshot("[{}]", "0-0/*"));
    }
}
