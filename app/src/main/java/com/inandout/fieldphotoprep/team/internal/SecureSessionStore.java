package com.inandout.fieldphotoprep.team.internal;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import org.json.JSONObject;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;

final class SecureSessionStore {
    static final String PREFERENCES_NAME = "field_photo_prep_team_session";
    static final String SESSION_BLOB_KEY = "encrypted_session_v1";
    private static final String KEY_ALIAS = "field_photo_prep_team_session_key_v1";

    interface Crypto {
        byte[] encrypt(byte[] plaintext) throws Exception;

        byte[] decrypt(byte[] ciphertext) throws Exception;
    }

    private final SharedPreferences preferences;
    private final Crypto crypto;

    SecureSessionStore(Context context) {
        this(context, new AndroidKeystoreCrypto());
    }

    SecureSessionStore(Context context, Crypto crypto) {
        this.preferences = context.getApplicationContext()
                .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE);
        this.crypto = crypto;
    }

    void save(SupabaseApi.AuthSession session) {
        try {
            JSONObject json = new JSONObject();
            json.put("access_token", session.accessToken);
            json.put("refresh_token", session.refreshToken);
            json.put("user_id", session.userId);
            json.put("email", session.email);
            json.put("role", session.role);
            json.put("organization_id", session.organizationId);
            json.put("expires_at", session.expiresAtEpochSeconds);

            byte[] encrypted = crypto.encrypt(json.toString().getBytes(StandardCharsets.UTF_8));
            String encoded = Base64.encodeToString(encrypted, Base64.NO_WRAP);
            if (!preferences.edit().putString(SESSION_BLOB_KEY, encoded).commit()) {
                throw new IllegalStateException("Unable to persist the encrypted Team session.");
            }
        } catch (Exception error) {
            throw new IllegalStateException("Unable to protect the Team session.", error);
        }
    }

    SupabaseApi.AuthSession load() {
        String encoded = preferences.getString(SESSION_BLOB_KEY, "");
        if (encoded == null || encoded.isEmpty()) {
            return null;
        }
        try {
            byte[] encrypted = Base64.decode(encoded, Base64.NO_WRAP);
            byte[] plaintext = crypto.decrypt(encrypted);
            JSONObject json = new JSONObject(new String(plaintext, StandardCharsets.UTF_8));

            String accessToken = json.getString("access_token");
            String refreshToken = json.getString("refresh_token");
            String userId = json.getString("user_id");
            String email = json.optString("email", "");
            String role = json.getString("role");
            String organizationId = json.getString("organization_id");
            long expiresAt = json.optLong("expires_at", 0L);

            if (refreshToken.isEmpty() || userId.isEmpty() || role.isEmpty() || organizationId.isEmpty()) {
                throw new IllegalStateException("Stored session identity is incomplete.");
            }

            return new SupabaseApi.AuthSession(
                    accessToken,
                    refreshToken,
                    userId,
                    email,
                    role,
                    organizationId,
                    expiresAt);
        } catch (Exception error) {
            clear();
            return null;
        }
    }

    void clear() {
        preferences.edit().remove(SESSION_BLOB_KEY).commit();
    }

    private static final class AndroidKeystoreCrypto implements Crypto {
        @Override
        public byte[] encrypt(byte[] plaintext) throws Exception {
            SecretKey key = getOrCreateKey();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key);
            byte[] iv = cipher.getIV();
            byte[] ciphertext = cipher.doFinal(plaintext);

            ByteBuffer envelope = ByteBuffer.allocate(4 + iv.length + ciphertext.length);
            envelope.putInt(iv.length);
            envelope.put(iv);
            envelope.put(ciphertext);
            return envelope.array();
        }

        @Override
        public byte[] decrypt(byte[] envelopeBytes) throws Exception {
            ByteBuffer envelope = ByteBuffer.wrap(envelopeBytes);
            if (envelope.remaining() < 5) {
                throw new IllegalArgumentException("Encrypted session envelope is invalid.");
            }
            int ivLength = envelope.getInt();
            if (ivLength < 12 || ivLength > 32 || envelope.remaining() <= ivLength) {
                throw new IllegalArgumentException("Encrypted session IV is invalid.");
            }
            byte[] iv = new byte[ivLength];
            envelope.get(iv);
            byte[] ciphertext = new byte[envelope.remaining()];
            envelope.get(ciphertext);

            SecretKey key = getOrCreateKey();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key, new javax.crypto.spec.GCMParameterSpec(128, iv));
            return cipher.doFinal(ciphertext);
        }

        private SecretKey getOrCreateKey() throws Exception {
            KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
            keyStore.load(null);
            SecretKey existing = (SecretKey) keyStore.getKey(KEY_ALIAS, null);
            if (existing != null) {
                return existing;
            }

            KeyGenerator generator = KeyGenerator.getInstance(
                    KeyProperties.KEY_ALGORITHM_AES,
                    "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setRandomizedEncryptionRequired(true)
                    .build());
            return generator.generateKey();
        }
    }
}
