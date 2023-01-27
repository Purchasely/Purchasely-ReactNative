package com.reactnativepurchasely

import android.app.Activity
import android.app.ActivityManager
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityManagerCompat
import androidx.core.view.WindowCompat
import io.purchasely.ext.PLYPresentation
import io.purchasely.ext.PLYPresentationViewProperties
import io.purchasely.ext.PLYProductViewResult
import io.purchasely.ext.Purchasely
import io.purchasely.models.PLYError
import io.purchasely.models.PLYPlan
import io.purchasely.views.parseColor
import java.lang.ref.WeakReference

class PLYPaywallActivity : AppCompatActivity() {

  private var presentationId: String? = null
  private var placementId: String? = null
  private var productId: String? = null
  private var planId: String? = null
  private var contentId: String? = null
  private var isFullScreen: Boolean = false
  private var backgroundColor: String? = null

  private var paywallView: View? = null

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    setContentView(R.layout.activity_ply_product_activity)

    moveTaskToBack(false)

    presentationId = intent.extras?.getString("presentationId")
    placementId = intent.extras?.getString("placementId")
    productId = intent.extras?.getString("productId")
    planId = intent.extras?.getString("planId")
    contentId = intent.extras?.getString("contentId")

    Purchasely.fetchPresentation(
      this,
      PLYPresentationViewProperties(
        presentationId = presentationId,
        placementId = placementId,
        contentId = contentId
      ),
      { result: PLYProductViewResult, plan: PLYPlan? ->
        PurchaselyModule.sendPurchaseResult(result, plan)
        supportFinishAfterTransition()
      }
    ) { presentation: PLYPresentation?, error: PLYError? ->
      PurchaselyModule.sendFetchResult(presentation, error)

      if(presentation?.view != null) {
        presentationId = presentation.id
        placementId = presentation.placementId

        paywallView = presentation.view
        findViewById<FrameLayout>(R.id.container).addView(paywallView)
      } else {
        finish()
      }
    }

  }

  fun updateDisplay(isFullScreen: Boolean, backgroundColor: String? = null) {
    this.isFullScreen = isFullScreen
    this.backgroundColor = backgroundColor
    if(isFullScreen) WindowCompat.setDecorFitsSystemWindows(window, false)

    if(backgroundColor != null) {
      try {
        val loadingBackgroundColor = backgroundColor.parseColor(Color.WHITE)
        findViewById<View>(R.id.container).setBackgroundColor(loadingBackgroundColor)
      } catch (e: Exception) {
        //do nothing
      }
    }
  }

  override fun onStart() {
    super.onStart()

    PurchaselyModule.productActivity = PurchaselyModule.ProductActivity(
      presentationId = presentationId,
      placementId = placementId,
      productId = productId,
      planId = planId,
      contentId = contentId,
      isFullScreen = isFullScreen,
      loadingBackgroundColor = backgroundColor
    ).apply {
      activity = WeakReference(this@PLYPaywallActivity)
    }
  }

  override fun onDestroy() {
    if(PurchaselyModule.productActivity?.activity?.get() == this) {
      PurchaselyModule.productActivity?.activity = null
    }
    super.onDestroy()
  }

  companion object {
    fun newIntent(activity: Activity?,
                  properties: PLYPresentationViewProperties) = Intent(activity, PLYPaywallActivity::class.java).apply {
      //remove old activity if still referenced to avoid issues
      val oldActivity = PurchaselyModule.productActivity?.activity?.get()
      oldActivity?.finish()
      PurchaselyModule.productActivity?.activity = null
      PurchaselyModule.productActivity = null
      //flags = Intent.FLAG_ACTIVITY_NEW_TASK xor Intent.FLAG_ACTIVITY_MULTIPLE_TASK

      putExtra("presentationId", properties.presentationId)
      putExtra("contentId", properties.contentId)
      putExtra("placementId", properties.placementId)
      putExtra("productId", properties.productId)
      putExtra("planId", properties.planId)
    }
  }

}
