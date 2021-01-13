package io.reactnativepurchasely

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.reactnativepurchasely.R
import io.purchasely.views.subscriptions.PLYSubscriptionsFragment

class PLYSubscriptionsActivity : AppCompatActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_ply_product_activity)

    supportFragmentManager
      .beginTransaction()
      .replace(R.id.fragmentContainer, PLYSubscriptionsFragment())
      .commit()
  }

}
