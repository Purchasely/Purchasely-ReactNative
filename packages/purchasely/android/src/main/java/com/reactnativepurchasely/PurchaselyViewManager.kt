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
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.common.MapBuilder
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.annotations.ReactPropGroup
import io.purchasely.ext.presentation.PLYPresentationBase
import io.purchasely.ext.presentation.PLYPresentationOutcome
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
 * The presentation is sourced either from a `placementId` prop, a
 * `presentation` map produced by the builder, or a bridge `requestId` already
 * preloaded via `request.preload()`. Outcomes flow back to JS through the
 * `PURCHASELY_PRESENTATION_DISMISSED` event, routed by `requestId` (or the
 * JS-generated `viewId` when there is no bridge request), mirroring the
 * full-screen `displayPresentation` contract.
 */
class PurchaselyViewManager(private val reactContext: ReactApplicationContext) : ViewGroupManager<FrameLayout>() {

  /** Props for a single mounted view, keyed by that view's own instance —
   * RN reuses this one manager across every `<PurchaselyView />`, so storing
   * props on the manager itself would let two simultaneous views clobber each
   * other's placementId/screenId/requestId/width/height. */
  internal class ViewProps {
    var placementId: String? = null
    var screenId: String? = null
    var requestId: String? = null
    var viewId: String? = null
    var width: Int? = null
    var height: Int? = null
    var layoutCallback: Choreographer.FrameCallback? = null
  }

  private val propsByView = mutableMapOf<FrameLayout, ViewProps>()

  internal fun propsFor(view: FrameLayout): ViewProps =
    propsByView.getOrPut(view) { ViewProps() }

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
    setupLayout(root, parentView)

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

    val props = propsByView[root] ?: ViewProps()
    // Guards against double-emitting a dismissal for the fresh/ad hoc path,
    // which wires this callback on both the request builder and the built
    // view (see `PurchaselyFragment.attachPurchaselyView`).
    var delivered = false
    val outcomeHandler: (PLYPresentationOutcome) -> Unit = { outcome ->
      if (!delivered) {
        delivered = true
        val routingId = props.requestId ?: props.viewId
        if (routingId != null) {
          PurchaselyModule.emitPresentationDismissed(reactContext, routingId, outcome)
        }
      }
    }

    val fragment = PurchaselyFragment(props.screenId, props.placementId, props.requestId, outcomeHandler)

    fm.beginTransaction()
      .setReorderingAllowed(true)
      .replace(reactNativeViewId, fragment, tag)
      .commitAllowingStateLoss()
  }

  /** Drives the embedded view's layout every frame. The callback is kept on the
   * view's own props so `onDropViewInstance` can cancel it — it reschedules
   * itself forever otherwise — and so a second `createFragment` (the
   * attach-to-window retry) does not start a competing loop. */
  private fun setupLayout(root: FrameLayout, view: View) {
    val props = propsFor(root)
    if (props.layoutCallback != null) return

    val callback = object : Choreographer.FrameCallback {
      override fun doFrame(frameTimeNanos: Long) {
        manuallyLayoutChildren(view, props)
        view.viewTreeObserver.dispatchOnGlobalLayout()
        Choreographer.getInstance().postFrameCallback(this)
      }
    }
    props.layoutCallback = callback
    Choreographer.getInstance().postFrameCallback(callback)
  }

  private fun manuallyLayoutChildren(view: View, props: ViewProps) {
    for (i in 0 until (view as ViewGroup).childCount) {
      val child = view.getChildAt(i)
      val parentView = child.parent as? View
      val width = resolveChildSize(props.width, child.measuredWidth, parentView?.measuredWidth ?: 0)
      val height = resolveChildSize(props.height, child.measuredHeight, parentView?.measuredHeight ?: 0)
      child.measure(
        View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
        View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
      )
      child.layout(0, 0, width, height)
    }
  }

  internal fun resolveChildSize(propSize: Int?, childMeasured: Int, parentMeasured: Int): Int =
    propSize ?: when {
      childMeasured > 0 -> childMeasured
      parentMeasured > 0 -> parentMeasured
      else -> 0
    }

  @ReactPropGroup(names = ["width", "height"], customType = "Style")
  fun setStyle(view: FrameLayout?, index: Int, value: Double) {
    view ?: return
    // 0 is RN's "unset" sentinel here, not a size: `ReactPropGroup` documents
    // that a dimension REMOVED from the JS style calls this setter back with
    // `defaultDouble`, which is 0.0. Taking it as a size pins the paywall to a
    // 0px box, so it maps to null and `resolveChildSize` falls back to the
    // measured size. `isFinite` guards the same way against a NaN or infinite
    // value, whose `toInt()` is also 0.
    //
    // `<PLYPresentationView />` passes `style={{ flex }}` only, so this setter
    // is reached solely by a consumer rendering the native component directly
    // with explicit dimensions.
    val size = if (value.isFinite() && value > 0) value.toInt() else null
    val props = propsFor(view)
    if (index == 0) props.width = size
    if (index == 1) props.height = size
  }

  @ReactProp(name = "placementId")
  fun setPlacementId(view: FrameLayout?, value: String?) {
    view ?: return
    propsFor(view).placementId = value
  }

  @ReactProp(name = "presentation")
  fun setPresentation(view: FrameLayout?, value: ReadableMap?) {
    view ?: return
    val props = propsFor(view)
    // The JS layer forwards either `id` (legacy) or `screenId`.
    props.screenId = value?.getString("screenId") ?: value?.getString("id")
    props.placementId = props.placementId ?: value?.getString("placementId")
  }

  @ReactProp(name = "requestId")
  fun setRequestId(view: FrameLayout?, value: String?) {
    view ?: return
    propsFor(view).requestId = value
  }

  @ReactProp(name = "viewId")
  fun setViewId(view: FrameLayout?, value: String?) {
    view ?: return
    propsFor(view).viewId = value
  }

  override fun onDropViewInstance(view: FrameLayout) {
    super.onDropViewInstance(view)
    // Hardening: a view that unmounts without ever dismissing (e.g. the host
    // navigates away) would otherwise leak its entry in these maps forever —
    // only `emitPresentationDismissed`/`closePresentation` purged them before.
    val props = propsByView.remove(view)
    props?.layoutCallback?.let { Choreographer.getInstance().removeFrameCallback(it) }
    props?.requestId?.let {
      PurchaselyModule.evictPresentationRequest(it)
    }
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
  }

  /**
   * Fragment hosting a `PLYPresentationView`. The presentation is built
   * lazily inside `onViewCreated` so the SDK can attach to the live Activity.
   */
  class PurchaselyFragment(
    private val screenId: String?,
    private val placementId: String?,
    private val requestId: String?,
    private val callback: (PLYPresentationOutcome) -> Unit
  ) : Fragment() {

    override fun onCreateView(
      inflater: LayoutInflater,
      container: ViewGroup?,
      savedInstanceState: Bundle?
    ): View = FrameLayout(inflater.context)

    private fun attachPurchaselyView(host: ViewGroup) {
      // v6 / iso iOS+Flutter: when a requestId is provided, reuse the
      // presentation the JS layer already preloaded (request.preload()) instead
      // of building + preloading a new one inside the view. The inline dismiss
      // path only invokes the `buildView` callback — the SDK never fires the
      // preload-time `onDismissed` for an embedded view (proven by E2E T25) —
      // so the outcome MUST be routed through `callback` here; the `delivered`
      // guard upstream absorbs any future double-fire.
      val preloaded = requestId?.let { PurchaselyModule.loadedPresentation(it) }
      if (preloaded != null) {
        // `preloadPresentation` (PurchaselyModule.wirePresentationCallbacks) always wires
        // `onCloseRequested` to forward a PRESENTATION_CLOSE_REQUESTED JS event — meant for a
        // full-screen non-dismissible modal, where the app decides how to react to a close
        // attempt. For a full-screen/flow presentation this is harmless: PLYFlowListener's own
        // onCloseRequested is consulted first and this callback never runs. An embedded view has
        // no flow listener, so the SDK's PLYPresentationView.close() falls straight to this
        // callback and — finding it non-null — invokes it INSTEAD of tearing down the view: the
        // native close (X) tap silently no-ops forever (root cause of E2E T25 hanging). Embedded
        // views have no such "ask before closing" contract, so clear it before building the view:
        // the tap now falls through to the SDK's default self-close (removeView →
        // onDetachedFromWindow → outcome callback).
        preloaded.onCloseRequested = null
        val pv: PLYPresentationView? =
          preloaded.buildView(host.context) { outcome -> callback(outcome) }
        pv?.let { host.addView(it) }
        return
      }

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
