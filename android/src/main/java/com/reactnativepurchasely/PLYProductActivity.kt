package com.reactnativepurchasely

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.purchasely.ext.PLYProductViewResult
import io.purchasely.ext.Purchasely
import io.purchasely.models.PLYPlan
import java.lang.ref.WeakReference

class PLYProductActivity : AppCompatActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    if(intent.extras?.getBoolean("isFullScreen") == true) {
      WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    setContentView(R.layout.activity_ply_product_activity)

    val presentationId = intent.extras?.getString("presentationId")
    val placementId = intent.extras?.getString("placementId")
    val productId = intent.extras?.getString("productId")
    val planId = intent.extras?.getString("planId")
    val contentId = intent.extras?.getString("contentId")

    val fragment = when {
        placementId?.isNotBlank() == true -> Purchasely.presentationFragmentForPlacement(
          placementId,
          contentId,
          null,
          callback
        )
        planId.isNullOrEmpty().not() -> Purchasely.planFragment(
          planId,
          presentationId,
          contentId,
          null,
          callback)
        productId.isNullOrEmpty().not() -> Purchasely.productFragment(
          productId,
          presentationId,
          contentId,
          null,
          callback)
        else -> Purchasely.presentationFragment(
          presentationId,
          contentId,
          null,
          callback)
    }

    if(fragment == null) {
      finish()
      return
    }

    supportFragmentManager
      .beginTransaction()
      .replace(R.id.fragmentContainer, fragment)
      .commit()

    PurchaselyModule.productActivity = PurchaselyModule.ProductActivity(
      presentationId = presentationId,
      placementId = placementId,
      productId = productId,
      planId = planId,
      contentId = contentId
    ).apply {
      activity = WeakReference(this@PLYProductActivity)
    }
  }

  override fun onDestroy() {
    PurchaselyModule.productActivity?.activity = null
    super.onDestroy()
  }

  private val callback: (PLYProductViewResult, PLYPlan?) -> Unit = { result, plan ->
    PurchaselyModule.sendPurchaseResult(result, plan)
  }

  companion object {
    fun newIntent(activity: Activity?) = Intent(activity, PLYProductActivity::class.java).apply {
      //flags = Intent.FLAG_ACTIVITY_NEW_TASK xor Intent.FLAG_ACTIVITY_MULTIPLE_TASK
    }
  }

}
