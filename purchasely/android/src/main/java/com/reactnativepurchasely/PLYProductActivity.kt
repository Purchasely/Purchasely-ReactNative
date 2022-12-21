package com.reactnativepurchasely

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.purchasely.ext.PLYPresentationViewProperties
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
  private var isFullScreen: Boolean = false
  private var backgroundColor: String? = null

  private var paywallView: View? = null

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    isFullScreen = intent.extras?.getBoolean("isFullScreen") ?: false
    backgroundColor = intent.extras?.getString("background_color")

    if(intent.extras?.getBoolean("isFullScreen") == true) {
      WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    setContentView(R.layout.activity_ply_product_activity)

    try {
      val loadingBackgroundColor = Color.parseColor(backgroundColor)
      findViewById<View>(R.id.container).setBackgroundColor(loadingBackgroundColor)
    } catch (e: Exception) {
      //do nothing
    }

    presentationId = intent.extras?.getString("presentationId")
    placementId = intent.extras?.getString("placementId")
    productId = intent.extras?.getString("productId")
    planId = intent.extras?.getString("planId")
    contentId = intent.extras?.getString("contentId")

    paywallView = Purchasely.presentationView(
      this@PLYProductActivity,
      PLYPresentationViewProperties(
        placementId = placementId,
        contentId = contentId,
        presentationId = presentationId,
        planId = planId,
        productId = productId,
        onLoaded = { onLoaded ->
          val backgroundPaywall = paywallView?.findViewById<FrameLayout>(io.purchasely.R.id.content)?.background
          if(backgroundPaywall != null) {
            findViewById<View>(R.id.container).background = backgroundPaywall
          }
        },
        onClose = {
          findViewById<FrameLayout>(R.id.container).removeAllViews()
        }
      ),
      callback
    )

    if(paywallView == null) {
      finish()
      return
    }


    findViewById<FrameLayout>(R.id.container).addView(paywallView)
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
    supportFinishAfterTransition()
  }

  companion object {
    fun newIntent(activity: Activity?,
                  properties: PLYPresentationViewProperties,
                  isFullScreen: Boolean = false,
                  backgroundColor: String?) = Intent(activity, PLYProductActivity::class.java).apply {
      //remove old activity if still referenced to avoid issues
      val oldActivity = PurchaselyModule.productActivity?.activity?.get()
      oldActivity?.finish()
      PurchaselyModule.productActivity?.activity = null
      PurchaselyModule.productActivity = null
      //flags = Intent.FLAG_ACTIVITY_NEW_TASK xor Intent.FLAG_ACTIVITY_MULTIPLE_TASK

      putExtra("background_color", backgroundColor)
      putExtra("isFullScreen", isFullScreen)

      putExtra("presentationId", properties.presentationId)
      putExtra("contentId", properties.contentId)
      putExtra("placementId", properties.placementId)
      putExtra("productId", properties.productId)
      putExtra("planId", properties.planId)
    }
  }

}
