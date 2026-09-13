package com.inandout.fieldphotoprep.team.internal;

import android.app.Activity;
import android.os.Bundle;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

public final class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        int padding = Math.round(24 * getResources().getDisplayMetrics().density);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setPadding(padding, padding, padding, padding);
        root.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        TextView title = new TextView(this);
        title.setText(R.string.app_name);
        title.setTextSize(24);
        title.setGravity(Gravity.CENTER);

        TextView status = new TextView(this);
        status.setText(R.string.shell_status);
        status.setTextSize(16);
        status.setGravity(Gravity.CENTER);
        status.setPadding(0, padding, 0, 0);

        TextView packageName = new TextView(this);
        packageName.setText(getString(R.string.package_label, getPackageName()));
        packageName.setTextSize(12);
        packageName.setGravity(Gravity.CENTER);
        packageName.setPadding(0, padding, 0, 0);

        root.addView(title);
        root.addView(status);
        root.addView(packageName);
        setContentView(root);
    }
}
