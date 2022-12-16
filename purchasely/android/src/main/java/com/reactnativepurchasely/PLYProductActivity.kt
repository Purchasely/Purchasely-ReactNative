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

  private var presentationId: String? = null
  private var placementId: String? = null
  private var productId: String? = null
  private var planId: String? = null
  private var contentId: String? = null

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    if(intent.extras?.getBoolean("isFullScreen") == true) {
      WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    setContentView(R.layout.activity_ply_product_activity)

    presentationId = intent.extras?.getString("presentationId")
    placementId = intent.extras?.getString("placementId")
    productId = intent.extras?.getString("productId")
    planId = intent.extras?.getString("planId")
    contentId = intent.extras?.getString("contentId")

    val placementId = placementId ?: ""

    val fragment = when {
        placementId.isNotBlank() -> Purchasely.presentationFragmentForPlacement(
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
  }

  override fun onStart() {
    super.onStart()

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
    if(PurchaselyModule.productActivity?.activity?.get() == this) {
      PurchaselyModule.productActivity?.activity = null
    }
    super.onDestroy()
  }

  private val callback: (PLYProductViewResult, PLYPlan?) -> Unit = { result, plan ->
    PurchaselyModule.sendPurchaseResult(result, plan)
  }

  companion object {
    fun newIntent(activity: Activity?) = Intent(activity, PLYProductActivity::class.java).apply {
      //remove old activity if still referenced to avoid issues
      val oldActivity = PurchaselyModule.productActivity?.activity?.get()
      oldActivity?.finish()
      PurchaselyModule.productActivity?.activity = null
      PurchaselyModule.productActivity = null
      //flags = Intent.FLAG_ACTIVITY_NEW_TASK xor Intent.FLAG_ACTIVITY_MULTIPLE_TASK
    }
  }

}
