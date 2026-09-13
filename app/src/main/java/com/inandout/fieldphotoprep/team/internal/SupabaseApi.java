package com.inandout.fieldphotoprep.team.internal;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

final class SupabaseApi {
    private static final int CONNECT_TIMEOUT_MS = 15_000;
    private static final int READ_TIMEOUT_MS = 20_000;

    static final class AuthSession {
        final String accessToken;
        final String userId;
        final String email;
        final String role;

        AuthSession(String accessToken, String userId, String email, String role) {
            this.accessToken = accessToken;
            this.userId = userId;
            this.email = email;
            this.role = role;
        }
    }

    static final class WorkOrder {
        final String id;
        final String woNumber;
        final String propertyAddress;
        final String workType;
        final String instructions;
        final String dueDate;
        final String fieldStatus;
        final String assignedUserId;

        WorkOrder(
                String id,
                String woNumber,
                String propertyAddress,
                String workType,
                String instructions,
                String dueDate,
                String fieldStatus,
                String assignedUserId) {
            this.id = id;
            this.woNumber = woNumber;
            this.propertyAddress = propertyAddress;
            this.workType = workType;
            this.instructions = instructions;
            this.dueDate = dueDate;
            this.fieldStatus = fieldStatus;
            this.assignedUserId = assignedUserId;
        }
    }

    AuthSession signIn(String email, String password) throws IOException, JSONException, ApiException {
        URL url = new URL(SupabaseConfig.PROJECT_URL + "/auth/v1/token?grant_type=password");
        HttpURLConnection connection = open(url);
        connection.setRequestMethod("POST");
        connection.setDoOutput(true);
        connection.setRequestProperty("apikey", SupabaseConfig.PUBLISHABLE_KEY);
        connection.setRequestProperty("Content-Type", "application/json");
        connection.setRequestProperty("Accept", "application/json");

        JSONObject request = new JSONObject();
        request.put("email", email);
        request.put("password", password);
        byte[] payload = request.toString().getBytes(StandardCharsets.UTF_8);
        connection.setFixedLengthStreamingMode(payload.length);

        try (OutputStream output = connection.getOutputStream()) {
            output.write(payload);
        }

        int status = connection.getResponseCode();
        String body = readBody(connection, status);
        connection.disconnect();

        if (status < 200 || status >= 300) {
            throw new ApiException(extractErrorMessage(status, body));
        }

        JSONObject response = new JSONObject(body);
        String accessToken = response.getString("access_token");
        JSONObject user = response.getJSONObject("user");
        String userId = user.getString("id");
        String signedInEmail = user.optString("email", email);
        JSONObject appMetadata = user.optJSONObject("app_metadata");
        String role = appMetadata == null ? "" : appMetadata.optString("role", "");

        return new AuthSession(accessToken, userId, signedInEmail, role);
    }

    List<WorkOrder> fetchWorkOrders(String accessToken) throws IOException, JSONException, ApiException {
        String query = "/rest/v1/work_orders"
                + "?select=id,wo_number,property_address,work_type,instructions,due_date,field_status,assigned_user_id"
                + "&order=due_date.asc,wo_number.asc";
        URL url = new URL(SupabaseConfig.PROJECT_URL + query);
        HttpURLConnection connection = open(url);
        connection.setRequestMethod("GET");
        connection.setRequestProperty("apikey", SupabaseConfig.PUBLISHABLE_KEY);
        connection.setRequestProperty("Authorization", "Bearer " + accessToken);
        connection.setRequestProperty("Accept", "application/json");

        int status = connection.getResponseCode();
        String body = readBody(connection, status);
        connection.disconnect();

        if (status < 200 || status >= 300) {
            throw new ApiException(extractErrorMessage(status, body));
        }

        JSONArray rows = new JSONArray(body);
        List<WorkOrder> workOrders = new ArrayList<>();
        for (int i = 0; i < rows.length(); i++) {
            JSONObject row = rows.getJSONObject(i);
            workOrders.add(new WorkOrder(
                    row.getString("id"),
                    row.optString("wo_number", ""),
                    row.optString("property_address", ""),
                    row.optString("work_type", ""),
                    row.isNull("instructions") ? "" : row.optString("instructions", ""),
                    row.optString("due_date", ""),
                    row.optString("field_status", ""),
                    row.isNull("assigned_user_id") ? "" : row.optString("assigned_user_id", "")));
        }
        return workOrders;
    }

    private static HttpURLConnection open(URL url) throws IOException {
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setConnectTimeout(CONNECT_TIMEOUT_MS);
        connection.setReadTimeout(READ_TIMEOUT_MS);
        connection.setUseCaches(false);
        return connection;
    }

    private static String readBody(HttpURLConnection connection, int status) throws IOException {
        InputStream stream = status >= 200 && status < 400
                ? connection.getInputStream()
                : connection.getErrorStream();
        if (stream == null) {
            return "";
        }

        StringBuilder result = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(stream, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                result.append(line);
            }
        }
        return result.toString();
    }

    private static String extractErrorMessage(int status, String body) {
        if (body != null && !body.isEmpty()) {
            try {
                JSONObject json = new JSONObject(body);
                String[] keys = {"msg", "message", "error_description", "error"};
                for (String key : keys) {
                    String value = json.optString(key, "").trim();
                    if (!value.isEmpty()) {
                        return value;
                    }
                }
            } catch (JSONException ignored) {
                // Fall through to a generic message. Never display raw response bodies.
            }
        }
        return "Request failed (HTTP " + status + ")";
    }

    static final class ApiException extends Exception {
        ApiException(String message) {
            super(message);
        }
    }
}
