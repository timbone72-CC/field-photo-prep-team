package com.inandout.fieldphotoprep.team.internal;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.content.SharedPreferences;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public final class SecureSessionStoreTest {
    private Context context;
    private SharedPreferences preferences;
    private SecureSessionStore store;

    @Before
    public void setUp() {
        context = RuntimeEnvironment.getApplication();
        preferences = context.getSharedPreferences(
                SecureSessionStore.PREFERENCES_NAME,
                Context.MODE_PRIVATE);
        preferences.edit().clear().commit();
        store = new SecureSessionStore(context, new ReversibleTestCrypto());
    }

    @Test
    public void encryptedSessionRoundTripsWithoutPlaintextTokensInPreferences() {
        SupabaseApi.AuthSession session = new SupabaseApi.AuthSession(
                "access-secret-value",
                "refresh-secret-value",
                "user-a",
                "contractor@example.invalid",
                "CONTRACTOR",
                "org-a",
                123456L);

        store.save(session);

        String raw = preferences.getString(SecureSessionStore.SESSION_BLOB_KEY, "");
        assertFalse(raw.contains("access-secret-value"));
        assertFalse(raw.contains("refresh-secret-value"));
        assertFalse(raw.contains("contractor@example.invalid"));

        SupabaseApi.AuthSession restored = store.load();
        assertEquals(session.accessToken, restored.accessToken);
        assertEquals(session.refreshToken, restored.refreshToken);
        assertEquals(session.userId, restored.userId);
        assertEquals(session.organizationId, restored.organizationId);
        assertEquals(session.role, restored.role);
        assertEquals(session.expiresAtEpochSeconds, restored.expiresAtEpochSeconds);
    }

    @Test
    public void malformedStoredSessionFailsClosedAndClearsReusableCredential() {
        preferences.edit()
                .putString(SecureSessionStore.SESSION_BLOB_KEY, "definitely-not-a-valid-session")
                .commit();

        assertNull(store.load());
        assertTrue(preferences.getString(SecureSessionStore.SESSION_BLOB_KEY, "").isEmpty());
    }

    @Test
    public void explicitClearRemovesReusableSession() {
        store.save(new SupabaseApi.AuthSession(
                "access",
                "refresh",
                "user-a",
                "contractor@example.invalid",
                "CONTRACTOR",
                "org-a",
                0L));

        store.clear();

        assertNull(store.load());
    }

    private static final class ReversibleTestCrypto implements SecureSessionStore.Crypto {
        @Override
        public byte[] encrypt(byte[] plaintext) {
            return transform(plaintext);
        }

        @Override
        public byte[] decrypt(byte[] ciphertext) {
            return transform(ciphertext);
        }

        private byte[] transform(byte[] source) {
            byte[] result = new byte[source.length];
            for (int i = 0; i < source.length; i++) {
                result[i] = (byte) (source[i] ^ 0x5A);
            }
            return result;
        }
    }
}
