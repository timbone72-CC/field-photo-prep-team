package com.inandout.fieldphotoprep.team.internal;

import static org.junit.Assert.*;

import android.content.Context;

import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class SessionCoordinatorTest {
    SecureSessionStore store;

    @Before
    public void setup() {
        Context c = RuntimeEnvironment.getApplication();
        c.getSharedPreferences(SecureSessionStore.PREFERENCES_NAME, Context.MODE_PRIVATE)
                .edit()
                .clear()
                .commit();
        store =
                new SecureSessionStore(
                        c,
                        new SecureSessionStore.Crypto() {
                            public byte[] encrypt(byte[] b) {
                                return b;
                            }

                            public byte[] decrypt(byte[] b) {
                                return b;
                            }
                        });
    }

    @Test
    public void signOutDuringRefreshCannotResurrectCredentials() throws Exception {
        CountDownLatch sent = new CountDownLatch(1), finish = new CountDownLatch(1);
        SessionCoordinator sessions =
                new SessionCoordinator(
                        store,
                        t -> {
                            sent.countDown();
                            assertTrue(finish.await(5, TimeUnit.SECONDS));
                            return expired("a", "rotated");
                        });
        long gen = sessions.beginLogin();
        sessions.install(gen, expired("a", "original"));
        ExecutorService e = Executors.newSingleThreadExecutor();
        Future<?> request =
                e.submit(
                        () -> {
                            assertThrows(
                                    SessionCoordinator.SessionChanged.class,
                                    () -> sessions.authorized(gen, "a", "org", true));
                        });
        assertTrue(sent.await(5, TimeUnit.SECONDS));
        sessions.signOut();
        finish.countDown();
        request.get(5, TimeUnit.SECONDS);
        e.shutdownNow();
        assertNull(sessions.load());
        assertTrue(sessions.generation() > gen);
    }

    @Test
    public void oldRefreshCannotOverwriteDifferentLogin() throws Exception {
        CountDownLatch sent = new CountDownLatch(1), finish = new CountDownLatch(1);
        SessionCoordinator sessions =
                new SessionCoordinator(
                        store,
                        t -> {
                            sent.countDown();
                            finish.await(5, TimeUnit.SECONDS);
                            return expired("a", "rotated");
                        });
        long gen = sessions.beginLogin();
        sessions.install(gen, expired("a", "original"));
        ExecutorService e = Executors.newSingleThreadExecutor();
        Future<?> request =
                e.submit(
                        () ->
                                assertThrows(
                                        SessionCoordinator.SessionChanged.class,
                                        () -> sessions.authorized(gen, "a", "org", true)));
        assertTrue(sent.await(5, TimeUnit.SECONDS));
        long login = sessions.beginLogin();
        assertTrue(sessions.install(login, expired("b", "b-token")));
        finish.countDown();
        request.get(5, TimeUnit.SECONDS);
        e.shutdownNow();
        assertEquals("b", sessions.load().userId);
        assertEquals("b-token", sessions.load().refreshToken);
        assertFalse(sessions.reject(gen));
        assertEquals("b", sessions.load().userId);
    }

    @Test
    public void concurrentRefreshUsesOneRotatingTokenOwner() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        SessionCoordinator sessions =
                new SessionCoordinator(
                        store,
                        t -> {
                            int n = calls.incrementAndGet();
                            assertEquals(n == 1 ? "original" : "rotated-1", t);
                            return expired("a", "rotated-" + n);
                        });
        long gen = sessions.beginLogin();
        sessions.install(gen, expired("a", "original"));
        ExecutorService e = Executors.newFixedThreadPool(2);
        Future<?> a =
                e.submit(
                        () -> {
                            try {
                                sessions.authorized(gen, "a", "org", true);
                            } catch (Exception x) {
                                throw new RuntimeException(x);
                            }
                        });
        Future<?> b =
                e.submit(
                        () -> {
                            try {
                                sessions.authorized(gen, "a", "org", true);
                            } catch (Exception x) {
                                throw new RuntimeException(x);
                            }
                        });
        a.get(5, TimeUnit.SECONDS);
        b.get(5, TimeUnit.SECONDS);
        e.shutdownNow();
        assertEquals(2, calls.get());
        assertEquals("rotated-2", sessions.load().refreshToken);
    }

    static SupabaseApi.AuthSession expired(String owner, String refresh) {
        return new SupabaseApi.AuthSession(
                "access", refresh, owner, "test@example.invalid", "CONTRACTOR", "org", 0);
    }
}
