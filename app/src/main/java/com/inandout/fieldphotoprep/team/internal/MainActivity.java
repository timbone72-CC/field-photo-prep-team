package com.inandout.fieldphotoprep.team.internal;

import android.app.Activity;
import android.graphics.Typeface;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private static final String RLS_CONTROL_WO = "TEST-0002-ADMIN-ONLY";

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final SupabaseApi api = new SupabaseApi();

    private EditText emailInput;
    private EditText passwordInput;
    private Button signInButton;
    private Button signOutButton;
    private ProgressBar progress;
    private TextView statusText;
    private TextView identityText;
    private TextView rlsText;
    private TextView workOrdersHeading;
    private LinearLayout workOrdersContainer;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(buildContent());
        showSignedOut();
    }

    private View buildContent() {
        int padding = dp(20);

        ScrollView scroll = new ScrollView(this);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(padding, padding, padding, padding);
        root.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        scroll.addView(root);

        TextView appName = text(getString(R.string.app_name), 14, false);
        root.addView(appName);

        TextView title = text(getString(R.string.phase1_title), 26, true);
        title.setPadding(0, dp(8), 0, dp(6));
        root.addView(title);

        TextView intro = text(getString(R.string.phase1_intro), 15, false);
        intro.setPadding(0, 0, 0, dp(18));
        root.addView(intro);

        emailInput = new EditText(this);
        emailInput.setHint(R.string.email_hint);
        emailInput.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS);
        emailInput.setSingleLine(true);
        emailInput.setLayoutParams(matchWrap());
        root.addView(emailInput);

        passwordInput = new EditText(this);
        passwordInput.setHint(R.string.password_hint);
        passwordInput.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        passwordInput.setSingleLine(true);
        passwordInput.setLayoutParams(matchWrap());
        root.addView(passwordInput);

        signInButton = new Button(this);
        signInButton.setText(R.string.sign_in);
        signInButton.setOnClickListener(v -> beginSignIn());
        signInButton.setLayoutParams(matchWrap());
        root.addView(signInButton);

        progress = new ProgressBar(this);
        LinearLayout.LayoutParams progressParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT);
        progressParams.gravity = Gravity.CENTER_HORIZONTAL;
        progressParams.topMargin = dp(12);
        progress.setLayoutParams(progressParams);
        root.addView(progress);

        statusText = text("", 15, false);
        statusText.setPadding(0, dp(12), 0, 0);
        root.addView(statusText);

        identityText = text("", 15, false);
        identityText.setPadding(0, dp(12), 0, 0);
        root.addView(identityText);

        rlsText = text("", 15, true);
        rlsText.setPadding(0, dp(12), 0, dp(12));
        root.addView(rlsText);

        signOutButton = new Button(this);
        signOutButton.setText(R.string.sign_out);
        signOutButton.setOnClickListener(v -> showSignedOut());
        signOutButton.setLayoutParams(matchWrap());
        root.addView(signOutButton);

        workOrdersHeading = text(getString(R.string.work_orders_heading), 20, true);
        workOrdersHeading.setPadding(0, dp(20), 0, dp(8));
        root.addView(workOrdersHeading);

        workOrdersContainer = new LinearLayout(this);
        workOrdersContainer.setOrientation(LinearLayout.VERTICAL);
        workOrdersContainer.setLayoutParams(matchWrap());
        root.addView(workOrdersContainer);

        return scroll;
    }

    private void beginSignIn() {
        String email = emailInput.getText().toString().trim();
        String password = passwordInput.getText().toString();
        if (email.isEmpty() || password.isEmpty()) {
            statusText.setText("Enter both email and password.");
            return;
        }

        setLoading(true, getString(R.string.signing_in));
        executor.execute(() -> {
            try {
                SupabaseApi.AuthSession session = api.signIn(email, password);
                postStatus(getString(R.string.loading_work));
                List<SupabaseApi.WorkOrder> workOrders = api.fetchWorkOrders(session.accessToken);
                mainHandler.post(() -> showSignedIn(session, workOrders));
            } catch (Exception error) {
                String message = error.getMessage();
                if (message == null || message.trim().isEmpty()) {
                    message = "Sign-in failed.";
                }
                String finalMessage = message;
                mainHandler.post(() -> {
                    passwordInput.setText("");
                    setLoading(false, finalMessage);
                });
            }
        });
    }

    private void showSignedIn(SupabaseApi.AuthSession session, List<SupabaseApi.WorkOrder> workOrders) {
        setLoading(false, "Signed in successfully.");
        passwordInput.setText("");
        emailInput.setVisibility(View.GONE);
        passwordInput.setVisibility(View.GONE);
        signInButton.setVisibility(View.GONE);
        signOutButton.setVisibility(View.VISIBLE);
        identityText.setVisibility(View.VISIBLE);
        rlsText.setVisibility(View.VISIBLE);
        workOrdersHeading.setVisibility(View.VISIBLE);
        workOrdersContainer.setVisibility(View.VISIBLE);

        identityText.setText("Account: " + session.email + "\nRole: " + session.role);

        boolean foreignAssignmentReturned = false;
        boolean controlReturned = false;
        for (SupabaseApi.WorkOrder workOrder : workOrders) {
            if (!session.userId.equals(workOrder.assignedUserId)) {
                foreignAssignmentReturned = true;
            }
            if (RLS_CONTROL_WO.equals(workOrder.woNumber)) {
                controlReturned = true;
            }
        }

        if ("CONTRACTOR".equals(session.role)
                && !foreignAssignmentReturned
                && !controlReturned
                && !workOrders.isEmpty()) {
            rlsText.setText("RLS CHECK: PASS\n"
                    + "Server returned " + workOrders.size() + " work order(s), all assigned to this account. "
                    + "The admin-only control WO was not returned. No client-side assignment filter was used.");
        } else if ("CONTRACTOR".equals(session.role)) {
            rlsText.setText("RLS CHECK: NEEDS REVIEW\n"
                    + "The contractor response was empty or contained a row that should not have been returned.");
        } else {
            rlsText.setText("Signed in as " + session.role
                    + ". Contractor-only RLS proof is evaluated when a CONTRACTOR account signs in.");
        }

        renderWorkOrders(workOrders);
    }

    private void renderWorkOrders(List<SupabaseApi.WorkOrder> workOrders) {
        workOrdersContainer.removeAllViews();
        if (workOrders.isEmpty()) {
            workOrdersContainer.addView(text(getString(R.string.no_work_orders), 15, false));
            return;
        }

        for (SupabaseApi.WorkOrder workOrder : workOrders) {
            LinearLayout card = new LinearLayout(this);
            card.setOrientation(LinearLayout.VERTICAL);
            card.setPadding(dp(12), dp(12), dp(12), dp(12));
            LinearLayout.LayoutParams cardParams = matchWrap();
            cardParams.bottomMargin = dp(10);
            card.setLayoutParams(cardParams);

            TextView number = text(workOrder.woNumber, 18, true);
            card.addView(number);
            card.addView(text(workOrder.propertyAddress, 16, false));
            card.addView(text("Work type: " + workOrder.workType, 14, false));
            card.addView(text("Due: " + workOrder.dueDate, 14, false));
            card.addView(text("Field status: " + workOrder.fieldStatus, 14, false));
            if (!workOrder.instructions.isEmpty()) {
                card.addView(text("Instructions: " + workOrder.instructions, 14, false));
            }

            workOrdersContainer.addView(card);
        }
    }

    private void showSignedOut() {
        passwordInput.setText("");
        emailInput.setVisibility(View.VISIBLE);
        passwordInput.setVisibility(View.VISIBLE);
        signInButton.setVisibility(View.VISIBLE);
        signInButton.setEnabled(true);
        signOutButton.setVisibility(View.GONE);
        progress.setVisibility(View.GONE);
        statusText.setText(R.string.signed_out);
        identityText.setText("");
        identityText.setVisibility(View.GONE);
        rlsText.setText("");
        rlsText.setVisibility(View.GONE);
        workOrdersHeading.setVisibility(View.GONE);
        workOrdersContainer.removeAllViews();
        workOrdersContainer.setVisibility(View.GONE);
    }

    private void setLoading(boolean loading, String message) {
        signInButton.setEnabled(!loading);
        emailInput.setEnabled(!loading);
        passwordInput.setEnabled(!loading);
        progress.setVisibility(loading ? View.VISIBLE : View.GONE);
        statusText.setText(message);
    }

    private void postStatus(String message) {
        mainHandler.post(() -> statusText.setText(message));
    }

    private TextView text(String value, float sizeSp, boolean bold) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(sizeSp);
        if (bold) {
            view.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        }
        view.setLayoutParams(matchWrap());
        return view;
    }

    private LinearLayout.LayoutParams matchWrap() {
        return new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    @Override
    protected void onDestroy() {
        executor.shutdownNow();
        super.onDestroy();
    }
}
