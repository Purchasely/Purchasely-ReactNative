package com.reactnativepurchasely

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.reactnativepurchasely.R
import io.purchasely.views.subscriptions.PLYSubscriptionsFragment
import io.purchasely.ext.Purchasely

class PLYSubscriptionsActivity : AppCompatActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_ply_product_activity)

    Purchasely.subscriptionsFragment()?.let {
      supportFragmentManager
        .beginTransaction()
        .addToBackStack(null)
        .replace(R.id.fragmentContainer, it, "SubscriptionsFragment")
        .commitAllowingStateLoss()
    }

    supportFragmentManager.addOnBackStackChangedListener {
        if(supportFragmentManager.backStackEntryCount == 0) {
            supportFinishAfterTransition()
        }
    }
  }

}
