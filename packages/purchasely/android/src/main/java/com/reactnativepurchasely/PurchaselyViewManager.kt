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
import android.content.res.Configuration

class PurchaselyViewManager(private val reactContext: ReactApplicationContext) : ViewGroupManager<FrameLayout>() {

  private var propWidth: Int? = null
  private var propHeight: Int? = null
  private var placementId: String? = null
  private var presentation: PLYPresentation? = null

  override fun getName(): String = "PurchaselyView"

  override fun createViewInstance(p0: ThemedReactContext): FrameLayout {
    return FrameLayout(p0).apply {
      id = View.generateViewId()
      layoutParams = FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT,
        FrameLayout.LayoutParams.MATCH_PARENT
      )
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
    Log.d("PurchaselyView", "Creating fragment in view having id=$reactNativeViewId.")
    val activity = (reactContext.currentActivity as? FragmentActivity) ?: return

    val parentView = root.findViewById<ViewGroup?>(reactNativeViewId) ?: return
    setupLayout(parentView)

    // Ensuring the container has the expected id
    if (parentView.id != reactNativeViewId) {
      parentView.id = reactNativeViewId
    }

    // Only transact when the container is attached to window
    if (!parentView.isAttachedToWindow) {
      parentView.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(v: View) {
          parentView.removeOnAttachStateChangeListener(this)
          createFragment(root, reactNativeViewId)
        }
        override fun onViewDetachedFromWindow(v: View) {}
      })
      return
    }

    val tag = reactNativeViewId.toString()
    val fm = activity.supportFragmentManager
    val existing = fm.findFragmentByTag(tag)
    if (existing != null && existing.isAdded) {
      // Already attached to this container. nothing to do.
      return
    }

    val fragment = PurchaselyFragment(presentation, placementId) { result, plan ->
      val productViewResult = when(result) {
        PLYProductViewResult.PURCHASED -> PLYProductViewResult.PURCHASED.ordinal
        PLYProductViewResult.CANCELLED -> PLYProductViewResult.CANCELLED.ordinal
        PLYProductViewResult.RESTORED -> PLYProductViewResult.RESTORED.ordinal
      }

      val map: MutableMap<String, Any?> = HashMap()
      map["result"] = productViewResult
      map["plan"] = PurchaselyModule.transformPlanToMap(plan)
      (promiseView ?: PurchaselyModule.defaultPurchasePromise)
        ?.resolve(Arguments.makeNativeMap(map))
      promiseView = null
    }

    // Safer transaction flags
    fm.beginTransaction()
      .setReorderingAllowed(true)
      .replace(reactNativeViewId, fragment, tag)
      .commitAllowingStateLoss()
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
    for (i in 0 until (view as ViewGroup).childCount) {
      val child = view.getChildAt(i)
      val width: Int = propWidth ?: when {
        child.measuredWidth > 0 -> child.measuredWidth
        (((child.parent as? View)?.measuredWidth) ?: 0) > 0 -> (child.parent as View).measuredWidth
        else -> 0
      }
      val height: Int = propHeight ?: when {
        child.measuredHeight > 0 -> child.measuredHeight
        (((child.parent as? View)?.measuredHeight) ?: 0) > 0 -> (child.parent as View).measuredHeight
        else -> 0
      }
      child.measure(
        View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
        View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
      child.layout(0, 0, width, height)
    }
  }

  @ReactPropGroup(names = ["width", "height"], customType = "Style")
  fun setStyle(view: FrameLayout?, index: Int, value: Double) {
    if (index == 0) propWidth = value.toInt()
    if (index == 1) propHeight = value.toInt()
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

  override fun onDropViewInstance(view: FrameLayout) {
    super.onDropViewInstance(view)
    val activity = (reactContext.currentActivity as? FragmentActivity) ?: return
    val fm = activity.supportFragmentManager
    val tag = view.id.toString()
    fm.findFragmentByTag(tag)?.let { frag ->
      fm.beginTransaction()
        .remove(frag)
        .commitAllowingStateLoss()
    }
  }

  companion object {
    const val COMMAND_CREATE = 1

    private var promiseView: Promise? = null
  }


  /**
   * Purchasely Fragment to host the PLYPresentationView
   */
  class PurchaselyFragment(
    private val presentation: PLYPresentation?,
    private val placementId: String?,
    private val callback: PLYPresentationResultHandler) : Fragment() {

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
      return FrameLayout(inflater.context)
    }

    private fun closeCallback() {
      (view as ViewGroup).removeAllViews()
      parentFragmentManager
        .beginTransaction()
        .remove(this)
        .commitAllowingStateLoss()
    }


    private fun buildPurchaselyView(view: View): PLYPresentationView? {
      val props = PLYPresentationProperties(
        placementId = placementId,
        onClose = { closeCallback() }
      )
      return if (presentation != null) {
        presentation.buildView(view.context, properties = props, callback = callback)
      } else {
        Purchasely.presentationView(view.context, properties = props, callback = callback)
      }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
      super.onViewCreated(view, savedInstanceState)
      (view as ViewGroup).addView(buildPurchaselyView(view))
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
      super.onConfigurationChanged(newConfig)
      val host = view as? ViewGroup ?: return
      host.removeAllViews()
      buildPurchaselyView(host)?.let { host.addView(it) }
    }
  }
}
