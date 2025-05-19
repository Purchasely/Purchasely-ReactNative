package com.reactnativepurchasely

import android.os.Bundle
import android.util.Log
import android.view.Choreographer
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.common.MapBuilder
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.annotations.ReactPropGroup
import io.purchasely.ext.PLYPresentation
import io.purchasely.ext.PLYPresentationResultHandler
import io.purchasely.ext.PLYPresentationProperties
import io.purchasely.ext.PLYProductViewResult
import io.purchasely.ext.Purchasely
import io.purchasely.views.presentation.PLYPresentationView


class PurchaselyViewManager(private val reactContext: ReactApplicationContext) : ViewGroupManager<FrameLayout>() {

  private var propWidth: Int? = null
  private var propHeight: Int? = null
  private var placementId: String? = null
  private var presentation: PLYPresentation? = null

  override fun getName(): String = "PurchaselyView"

  override fun createViewInstance(p0: ThemedReactContext): FrameLayout {
    return FrameLayout(p0).apply {
      layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
    }
  }

  override fun getCommandsMap(): Map<String, Int>? {
    return MapBuilder.of<String, Int>("create", COMMAND_CREATE)
  }

  override fun receiveCommand(root: FrameLayout, commandId: Int, args: ReadableArray?) {
    Log.d("PurchaselyView", "Received a command having commandId=$commandId.")
    super.receiveCommand(root, commandId, args)
    val reactNativeViewId = args?.getInt(0) ?: return

    when (commandId) {
      COMMAND_CREATE -> createFragment(root, reactNativeViewId)
      else -> {}
    }
  }

  override fun receiveCommand(root: FrameLayout, commandId: String?, args: ReadableArray?) {
    super.receiveCommand(root, commandId, args)

    Log.d("PurchaselyView", "Received a command having commandId=$commandId.")
    super.receiveCommand(root, commandId, args)
    val reactNativeViewId = args?.getInt(0) ?: return
    val commandIdInt = commandId?.toIntOrNull() ?: return

    when (commandIdInt) {
      COMMAND_CREATE -> createFragment(root, reactNativeViewId)
      else -> {}
    }
  }

  private fun createFragment(root: FrameLayout, reactNativeViewId: Int) {
    val parentView = root.findViewById(reactNativeViewId) as ViewGroup
    setupLayout(parentView)

    val fragment = PurchaselyFragment(presentation, placementId) { result, plan ->
      val productViewResult = when(result) {
        PLYProductViewResult.PURCHASED -> PLYProductViewResult.PURCHASED.ordinal
        PLYProductViewResult.CANCELLED -> PLYProductViewResult.CANCELLED.ordinal
        PLYProductViewResult.RESTORED -> PLYProductViewResult.RESTORED.ordinal
      }

      val map: MutableMap<String, Any?> = HashMap()
      map["result"] = productViewResult
      map["plan"] = PurchaselyModule.transformPlanToMap(plan)
      promiseView?.resolve(Arguments.makeNativeMap(map)) ?: PurchaselyModule.defaultPurchasePromise?.resolve(
        Arguments.makeNativeMap(map))
    }
    (reactContext.currentActivity as? FragmentActivity)?.supportFragmentManager
      ?.beginTransaction()
      ?.replace(reactNativeViewId, fragment, reactNativeViewId.toString())
      ?.commit()
  }

  fun setupLayout(view: View) {
    Choreographer.getInstance().postFrameCallback(object : Choreographer.FrameCallback {
      override fun doFrame(frameTimeNanos: Long) {
        manuallyLayoutChildren(view)
        view.viewTreeObserver.dispatchOnGlobalLayout()
        Choreographer.getInstance().postFrameCallback(this)
      }
    })
  }

  /**
   * Layout all children properly
   */
  fun manuallyLayoutChildren(view: View) {
    // propWidth and propHeight coming from react-native props
    val width: Int = propWidth ?: when {
      view.width > 0 -> view.width
      (((view.parent as? View)?.width) ?: 0) > 0 -> (view.parent as View).width
      else -> 0
    }
    val height: Int = propHeight ?: when {
      view.height > 0 -> view.height
      (((view.parent as? View)?.height) ?: 0) > 0 -> (view.parent as View).height
      else -> 0
    }

    view.measure(
      View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
    )
    view.layout(0, 0, width, height)
  }

  @ReactPropGroup(names = ["width", "height"], customType = "Style")
  fun setStyle(view: FrameLayout?, index: Int, value: Double) {
    if (index == 0) {
      propWidth = value.toInt()
    }
    if (index == 1) {
      propHeight = value.toInt()
    }
  }

  @ReactProp(name = "placementId")
  fun setPlacementId(view: FrameLayout?, value: String?) {
    placementId = value
  }

  @ReactProp(name = "presentation")
  fun setPresentation(view: FrameLayout?, value: ReadableMap?) {
    presentation = PurchaselyModule.presentationsLoaded.lastOrNull {
      it.id == value?.getString("id")
        && it.placementId == value?.getString("placementId")
    }
  }

  @ReactMethod
  fun onPresentationClosed(promise: Promise) {
    promiseView = promise
    Log.d("PurchaselyView", "onPresentationClosed")
  }

  companion object {
    const val COMMAND_CREATE = 1

    private var promiseView: Promise? = null
  }

  class PurchaselyFragment(
    private val presentation: PLYPresentation?,
    private val placementId: String?,
    private val callback: PLYPresentationResultHandler) : Fragment() {
    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
      return FrameLayout(inflater.context)
    }

    private fun closeCallback() {
        (view as ViewGroup).removeAllViews()
        activity?.supportFragmentManager?.beginTransaction()?.remove(this)?.commitAllowingStateLoss()
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
      super.onViewCreated(view, savedInstanceState)

      val purchaselyView: PLYPresentationView?
      if(presentation != null) {
        purchaselyView = presentation.buildView(view.context,
          properties = PLYPresentationProperties(
            onClose = {
              closeCallback()
            }
          ), callback = callback)
      } else {
        purchaselyView = Purchasely.presentationView(view.context,
          properties = PLYPresentationProperties(
            placementId = placementId,
            onClose = {
              closeCallback()
            }
          ),
          callback = callback)
      }

      (view as ViewGroup).addView(purchaselyView)
    }
  }

}
