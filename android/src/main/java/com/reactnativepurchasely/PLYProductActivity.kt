package com.reactnativepurchasely

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import com.reactnativepurchasely.R
import io.purchasely.ext.PLYProductViewResult
import io.purchasely.ext.ProductViewResultListener
import io.purchasely.ext.Purchasely
import io.purchasely.models.PLYPlan

class PLYProductActivity : AppCompatActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_ply_product_activity)

    val presentationId = intent.extras?.getString("presentationId")

    val fragment: Fragment = Purchasely.presentationFragment(
      presentationId) { result, plan ->
      PurchaselyModule.sendPurchaseResult(result, plan)
    }

    supportFragmentManager
      .beginTransaction()
      .replace(R.id.fragmentContainer, fragment)
      .commit()
  }

}
