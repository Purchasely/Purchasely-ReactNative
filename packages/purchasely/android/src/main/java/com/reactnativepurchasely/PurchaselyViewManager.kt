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
import io.purchasely.ext.presentation.PLYPresentationBase
import io.purchasely.ext.presentation.PLYPresentationOutcome
import io.purchasely.ext.presentation.PLYPurchaseResult
import io.purchasely.ext.presentation.preload
import io.purchasely.views.presentation.PLYPresentationView
import android.content.res.Configuration
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * View manager for `<PLYPresentationView />`. Hosts a `PLYPresentationView`
 * inside a React-Native managed Fragment.
 *
 * The presentation is sourced either from a `placementId` prop or from a
 * `presentation` map produced by the builder. Outcomes flow back to JS
 * through the same `PURCHASELY_PRESENTATION_DISMISSED`-friendly shape used by the v5 view
 * (`{ result, plan }`), preserving the existing `onPresentationClosed` contract.
 */
class PurchaselyViewManager(private val reactContext: ReactApplicationContext) : ViewGroupManager<FrameLayout>() {

  private var propWidth: Int? = null
  private var propHeight: Int? = null
  private var placementId: String? = null
  private var screenId: String? = null

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

  override fun getCommandsMap(): Map<String, Int> =
    MapBuilder.of<String, Int>("create", COMMAND_CREATE)

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

    if (parentView.id != reactNativeViewId) {
      parentView.id = reactNativeViewId
    }

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
      return
    }

    val outcomeHandler: (PLYPresentationOutcome) -> Unit = { outcome ->
      val resultOrdinal = when (outcome.purchaseResult) {
        PLYPurchaseResult.PURCHASED -> 0
        PLYPurchaseResult.RESTORED -> 2
        PLYPurchaseResult.CANCELLED -> 1
        null -> 1
      }
      val map: MutableMap<String, Any?> = HashMap()
      map["result"] = resultOrdinal
      map["plan"] = PurchaselyModule.transformPlanToMap(outcome.plan)
      promiseView?.resolve(Arguments.makeNativeMap(map))
      promiseView = null
    }

    val fragment = PurchaselyFragment(screenId, placementId, outcomeHandler)

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

  fun manuallyLayoutChildren(view: View) {
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
        View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
      )
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
    // The JS layer forwards either `id` (legacy) or `screenId`.
    screenId = value?.getString("screenId") ?: value?.getString("id")
    placementId = placementId ?: value?.getString("placementId")
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
   * Fragment hosting a `PLYPresentationView`. The presentation is built
   * lazily inside `onViewCreated` so the SDK can attach to the live Activity.
   */
  class PurchaselyFragment(
    private val screenId: String?,
    private val placementId: String?,
    private val callback: (PLYPresentationOutcome) -> Unit
  ) : Fragment() {

    override fun onCreateView(
      inflater: LayoutInflater,
      container: ViewGroup?,
      savedInstanceState: Bundle?
    ): View = FrameLayout(inflater.context)

    private fun attachPurchaselyView(host: ViewGroup) {
      val prepared: PLYPresentationBase.Prepared = PLYPresentationBase.builder()
        .also { b ->
          placementId?.let { b.placementId(it) }
          screenId?.let { b.screenId(it) }
        }
        .onDismissed { outcome -> callback(outcome) }
        .build()

      CoroutineScope(Dispatchers.Main).launch {
        try {
          val loaded = withContext(Dispatchers.Default) { prepared.preload() }
          val pv: PLYPresentationView? =
            loaded.buildView(host.context) { outcome -> callback(outcome) }
          pv?.let { host.addView(it) }
        } catch (e: Throwable) {
          Log.w("PurchaselyView", "Unable to build presentation view: ${e.message}", e)
        }
      }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
      super.onViewCreated(view, savedInstanceState)
      attachPurchaselyView(view as ViewGroup)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
      super.onConfigurationChanged(newConfig)
      val host = view as? ViewGroup ?: return
      host.removeAllViews()
      attachPurchaselyView(host)
    }
  }
}
