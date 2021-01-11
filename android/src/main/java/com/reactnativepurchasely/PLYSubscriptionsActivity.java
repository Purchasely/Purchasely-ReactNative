package com.reactnativepurchasely;

import android.os.Bundle;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;

import io.purchasely.ext.Purchasely;
import io.purchasely.views.subscriptions.PLYSubscriptionsFragment;

public class PLYSubscriptionsActivity extends AppCompatActivity {

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_ply_product_activity);

        getSupportFragmentManager()
                .beginTransaction()
                .replace(R.id.fragmentContainer, new PLYSubscriptionsFragment())
                .commit();
    }
}
