package com.reactnativepurchasely;

import android.os.Bundle;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;

import org.jetbrains.annotations.NotNull;

import io.purchasely.ext.PLYProductViewResult;
import io.purchasely.ext.ProductViewResultListener;
import io.purchasely.ext.Purchasely;
import io.purchasely.models.PLYPlan;

public class PLYProductActivity extends AppCompatActivity {

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_ply_product_activity);

        String productId = getIntent().getExtras().getString("productId");
        String presentationId = getIntent().getExtras().getString("presentationId");

        if(productId == null) {
            supportFinishAfterTransition();
            return;
        }

        Fragment fragment = Purchasely.productFragment(productId, presentationId, (plyProductViewResult, plyPlan) -> {

        });

        getSupportFragmentManager()
                .beginTransaction()
                .replace(R.id.fragmentContainer, fragment)
                .commit();
    }
}
