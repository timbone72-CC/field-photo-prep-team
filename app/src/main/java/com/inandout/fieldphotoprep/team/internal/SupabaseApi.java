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

final class SupabaseApi implements AssignmentRepository.Remote {
    private static final int CONNECT_TIMEOUT_MS = 15_000;
    private static final int READ_TIMEOUT_MS = 20_000;

    static final class AuthSession {
        final String accessToken;
        final String refreshToken;
        final String userId;
        final String email;
        final String role;
        final String organizationId;
        final long expiresAtEpochSeconds;

        AuthSession(
                String accessToken,
                String refreshToken,
                String userId,
                String email,
                String role,
                String organizationId,
                long expiresAtEpochSeconds) {
            this.accessToken = accessToken;
            this.refreshToken = refreshToken;
            this.userId = userId;
            this.email = email;
            this.role = role;
            this.organizationId = organizationId;
            this.expiresAtEpochSeconds = expiresAtEpochSeconds;
        }
    }

    static final class WorkOrder {
        final String id;
        final String organizationId;
        final String currentRunId;
        final int currentRunSequence;
        final String woNumber;
        final String propertyAddress;
        final String workType;
        final String instructions;
        final String dueDate;
        final String fieldStatus;
        final String assignedUserId;
        final String pendingAssigneeUserId;
        final String reassignmentRequestedAt;
        final String assignmentReceivedAt;
        final String startedAt;
        final String fieldCompletedAt;
        final String serverUpdatedAt;

        WorkOrder(
                String id,
                String organizationId,
                String currentRunId,
                int currentRunSequence,
                String woNumber,
                String propertyAddress,
                String workType,
                String instructions,
                String dueDate,
                String fieldStatus,
                String assignedUserId,
                String pendingAssigneeUserId,
                String reassignmentRequestedAt,
                String assignmentReceivedAt,
                String startedAt,
                String fieldCompletedAt,
                String serverUpdatedAt) {
            this.id = id;
            this.organizationId = organizationId;
            this.currentRunId = currentRunId;
            this.currentRunSequence = currentRunSequence;
            this.woNumber = woNumber;
            this.propertyAddress = propertyAddress;
            this.workType = workType;
            this.instructions = instructions;
            this.dueDate = dueDate;
            this.fieldStatus = fieldStatus;
            this.assignedUserId = assignedUserId;
            this.pendingAssigneeUserId = pendingAssigneeUserId;
            this.reassignmentRequestedAt = reassignmentRequestedAt;
            this.assignmentReceivedAt = assignmentReceivedAt;
            this.startedAt = startedAt;
            this.fieldCompletedAt = fieldCompletedAt;
            this.serverUpdatedAt = serverUpdatedAt;
        }
    }

    AuthSession signIn(String email, String password) throws IOException, JSONException, ApiException {
        JSONObject request = new JSONObject();
        request.put("email", email);
        request.put("password", password);
        return tokenRequest("password", request, email);
    }

    AuthSession refreshSession(String refreshToken) throws IOException, JSONException, ApiException {
        if (refreshToken == null || refreshToken.trim().isEmpty()) {
            throw new ApiException(401, "No reusable Team session is available.");
        }
        JSONObject request = new JSONObject();
        request.put("refresh_token", refreshToken);
        return tokenRequest("refresh_token", request, "");
    }

    private AuthSession tokenRequest(String grantType, JSONObject request, String fallbackEmail)
            throws IOException, JSONException, ApiException {
        URL url = new URL(SupabaseConfig.PROJECT_URL + "/auth/v1/token?grant_type=" + grantType);
        HttpURLConnection connection = open(url);
        connection.setRequestMethod("POST");
        connection.setDoOutput(true);
        connection.setRequestProperty("apikey", SupabaseConfig.PUBLISHABLE_KEY);
        connection.setRequestProperty("Content-Type", "application/json");
        connection.setRequestProperty("Accept", "application/json");

        byte[] payload = request.toString().getBytes(StandardCharsets.UTF_8);
        connection.setFixedLengthStreamingMode(payload.length);
        try (OutputStream output = connection.getOutputStream()) {
            output.write(payload);
        }

        int status = connection.getResponseCode();
        String body = readBody(connection, status);
        connection.disconnect();
        if (status < 200 || status >= 300) {
            throw new ApiException(status, extractErrorMessage(status, body));
        }

        JSONObject response = new JSONObject(body);
        String accessToken = response.getString("access_token");
        String refreshToken = response.getString("refresh_token");
        JSONObject user = response.getJSONObject("user");
        String userId = user.getString("id");
        String signedInEmail = user.optString("email", fallbackEmail);
        JSONObject appMetadata = user.optJSONObject("app_metadata");
        String role = appMetadata == null ? "" : appMetadata.optString("role", "");
        String organizationId = appMetadata == null
                ? ""
                : appMetadata.optString("organization_id", "");
        long expiresAt = response.optLong("expires_at", 0L);
        if (expiresAt <= 0L) {
            long expiresIn = response.optLong("expires_in", 0L);
            expiresAt = expiresIn <= 0L
                    ? 0L
                    : (System.currentTimeMillis() / 1000L) + expiresIn;
        }

        if (userId.isEmpty() || role.isEmpty() || organizationId.isEmpty()) {
            throw new ApiException(403, "Team authorization metadata is incomplete.");
        }

        return new AuthSession(
                accessToken,
                refreshToken,
                userId,
                signedInEmail,
                role,
                organizationId,
                expiresAt);
    }

    @Override
    public List<WorkOrder> fetchWorkOrders(String accessToken)
            throws IOException, JSONException, ApiException {
        String query = "/rest/v1/work_orders"
                + "?select=id,organization_id,current_run_id,current_run_sequence,wo_number,property_address,work_type,instructions,due_date,field_status,assigned_user_id,pending_assignee_user_id,reassignment_requested_at,assignment_received_at,started_at,field_completed_at,updated_at"
                + "&order=due_date.asc,wo_number.asc";
        URL url = new URL(SupabaseConfig.PROJECT_URL + query);
        HttpURLConnection connection = open(url);
        connection.setRequestMethod("GET");
        addAuthHeaders(connection, accessToken);

        int status = connection.getResponseCode();
        String body = readBody(connection, status);
        connection.disconnect();
        if (status < 200 || status >= 300) {
            throw new ApiException(status, extractErrorMessage(status, body));
        }

        JSONArray rows = new JSONArray(body);
        List<WorkOrder> workOrders = new ArrayList<>();
        for (int i = 0; i < rows.length(); i++) {
            JSONObject row = rows.getJSONObject(i);
            workOrders.add(new WorkOrder(
                    row.getString("id"),
                    row.optString("organization_id", ""),
                    nullableString(row, "current_run_id"),
                    row.optInt("current_run_sequence", 0),
                    row.optString("wo_number", ""),
                    row.optString("property_address", ""),
                    row.optString("work_type", ""),
                    nullableString(row, "instructions"),
                    row.optString("due_date", ""),
                    row.optString("field_status", ""),
                    nullableString(row, "assigned_user_id"),
                    nullableString(row, "pending_assignee_user_id"),
                    nullableString(row, "reassignment_requested_at"),
                    nullableString(row, "assignment_received_at"),
                    nullableString(row, "started_at"),
                    nullableString(row, "field_completed_at"),
                    nullableString(row, "updated_at")));
        }
        return workOrders;
    }

    @Override
    public void acknowledgeAssignmentReceived(String accessToken, String workOrderId)
            throws IOException, JSONException, ApiException {
        JSONObject request = new JSONObject();
        request.put("p_work_order_id", workOrderId);
        postRpc(accessToken, "acknowledge_assignment_received", request);
    }

    void respondReassignment(String accessToken, String workOrderId, boolean accept)
            throws IOException, JSONException, ApiException {
        JSONObject request = new JSONObject();
        request.put("p_work_order_id", workOrderId);
        request.put("p_accept", accept);
        postRpc(accessToken, "respond_reassignment", request);
    }

    private void postRpc(String accessToken, String functionName, JSONObject request)
            throws IOException, ApiException {
        URL url = new URL(SupabaseConfig.PROJECT_URL + "/rest/v1/rpc/" + functionName);
        HttpURLConnection connection = open(url);
        connection.setRequestMethod("POST");
        connection.setDoOutput(true);
        addAuthHeaders(connection, accessToken);
        connection.setRequestProperty("Content-Type", "application/json");
        byte[] payload = request.toString().getBytes(StandardCharsets.UTF_8);
        connection.setFixedLengthStreamingMode(payload.length);
        try (OutputStream output = connection.getOutputStream()) {
            output.write(payload);
        }

        int status = connection.getResponseCode();
        String body = readBody(connection, status);
        connection.disconnect();
        if (status < 200 || status >= 300) {
            throw new ApiException(status, extractErrorMessage(status, body));
        }
    }

    private static void addAuthHeaders(HttpURLConnection connection, String accessToken) {
        connection.setRequestProperty("apikey", SupabaseConfig.PUBLISHABLE_KEY);
        connection.setRequestProperty("Authorization", "Bearer " + accessToken);
        connection.setRequestProperty("Accept", "application/json");
    }

    private static String nullableString(JSONObject row, String key) {
        return row.isNull(key) ? "" : row.optString(key, "");
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
        final int statusCode;

        ApiException(int statusCode, String message) {
            super(message);
            this.statusCode = statusCode;
        }

        boolean isAuthenticationRejection() {
            return statusCode == 400 || statusCode == 401 || statusCode == 403;
        }
    }
}
