package com.reactnativepurchasely

import android.util.Log
import android.view.Choreographer
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
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
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * View manager for `<PLYPresentationView />`, hosting a `PLYPresentationView`
 * in a plain child view of the RN view. No Fragment: a fragment container is
 * looked up by id in the Activity window, which fails for a view that unmounts
 * before the transaction runs, leaves the window, or lives in an RN `<Modal>`.
 * The presentation comes from a `placementId`, a `presentation` map, or an already-preloaded `requestId`. Outcomes go back to
 * JS as `PURCHASELY_PRESENTATION_DISMISSED`, routed by `requestId` or `viewId`.
 */
class PurchaselyViewManager(private val reactContext: ReactApplicationContext) : ViewGroupManager<FrameLayout>() {

  /** Per-view props. RN reuses ONE manager for every `<PurchaselyView />`, so
   * anything stored on the manager itself gets clobbered by a second view. */
  internal class ViewProps {
    var placementId: String? = null
    var screenId: String? = null
    var requestId: String? = null
    var viewId: String? = null
    var width: Int? = null
    var height: Int? = null
    var layoutCallback: Choreographer.FrameCallback? = null
    var host: ViewGroup? = null
    var buildJob: Job? = null
    var pendingAttach: View.OnAttachStateChangeListener? = null
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
      COMMAND_CREATE -> createPresentation(root, reactNativeViewId)
      else -> {}
    }
  }

  override fun receiveCommand(root: FrameLayout, commandId: String?, args: ReadableArray?) {
    super.receiveCommand(root, commandId, args)
    Log.d("PurchaselyView", "Received a command having commandId=$commandId.")
    val reactNativeViewId = args?.getInt(0) ?: return
    val commandIdInt = commandId?.toIntOrNull() ?: return

    when (commandIdInt) {
      COMMAND_CREATE -> createPresentation(root, reactNativeViewId)
      else -> {}
    }
  }

  private fun createPresentation(root: FrameLayout, reactNativeViewId: Int) {
    Log.d("PurchaselyView", "Creating presentation in view having id=$reactNativeViewId.")
    // The SDK needs a FragmentActivity: it is the view's LifecycleOwner and shows
    // the web checkout dialog. `root.context` is RN's ThemedReactContext.
    val activity = (reactContext.currentActivity as? FragmentActivity) ?: return
    val parentView = root.findViewById<ViewGroup?>(reactNativeViewId) ?: return
    val props = propsFor(root)
    if (props.host != null) return
    setupLayout(root, parentView)

    // The fresh/ad hoc path wires this callback twice (builder + built view),
    // so guard against emitting the dismissal twice.
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

    val host = FrameLayout(activity)
    props.host = host
    // No rebuild on a configuration change: the SDK view sends its outcome when
    // it leaves the window, so a rebuild dismisses the paywall for JS.
    parentView.addView(host)
    attachPurchaselyView(host, props, outcomeHandler)
  }

  private fun attachPurchaselyView(
    host: ViewGroup,
    props: ViewProps,
    callback: (PLYPresentationOutcome) -> Unit
  ) {
    cancelPendingBuild(host, props)
    // A requestId means JS already preloaded this presentation: reuse it.
    // The SDK never fires the preload-time `onDismissed` for an embedded view
    // (E2E T25), so the outcome must be routed through `callback` here.
    val preloaded = props.requestId?.let { PurchaselyModule.loadedPresentation(it) }
    if (preloaded != null) {
      // `preloadPresentation` always wires `onCloseRequested`, which only makes
      // sense for a non-dismissible full-screen modal. An embedded view has no
      // flow listener, so `close()` invokes that callback INSTEAD of tearing the
      // view down and the X tap no-ops forever (this hung E2E T25). Clear it so
      // the tap falls through to the SDK's default self-close.
      preloaded.onCloseRequested = null
      buildWhenAttached(host, props) { preloaded.buildView(host.context) { outcome -> callback(outcome) } }
      return
    }

    val prepared: PLYPresentationBase.Prepared = PLYPresentationBase.builder()
      .also { b ->
        props.placementId?.let { b.placementId(it) }
        props.screenId?.let { b.screenId(it) }
      }
      .onDismissed { outcome -> callback(outcome) }
      .build()

    props.buildJob = CoroutineScope(Dispatchers.Main).launch {
      try {
        val loaded = withContext(Dispatchers.Default) { prepared.preload() }
        buildWhenAttached(host, props) { loaded.buildView(host.context) { outcome -> callback(outcome) } }
      } catch (e: CancellationException) {
        throw e
      } catch (e: Throwable) {
        Log.w("PurchaselyView", "Unable to build presentation view: ${e.message}", e)
      }
    }
  }

  /**
   * Builds the SDK view and adds it while [host] is attached. The SDK view takes
   * its outcome callback from a global request when it attaches, and the next
   * `buildView` replaces that request: a view built detached gets the outcome
   * callback of another paywall. A host dropped meanwhile builds nothing.
   */
  private fun buildWhenAttached(host: ViewGroup, props: ViewProps, build: () -> PLYPresentationView?) {
    if (props.host !== host) return
    if (host.isAttachedToWindow) {
      build()?.let { host.addView(it) }
      return
    }
    val listener = object : View.OnAttachStateChangeListener {
      override fun onViewAttachedToWindow(v: View) {
        host.removeOnAttachStateChangeListener(this)
        props.pendingAttach = null
        buildWhenAttached(host, props, build)
      }
      override fun onViewDetachedFromWindow(v: View) {}
    }
    props.pendingAttach = listener
    host.addOnAttachStateChangeListener(listener)
  }

  /** Stops the build in progress, so a second build or a drop leaves no second paywall. */
  private fun cancelPendingBuild(host: ViewGroup, props: ViewProps) {
    props.buildJob?.cancel()
    props.pendingAttach?.let { host.removeOnAttachStateChangeListener(it) }
    props.pendingAttach = null
  }

  /** Lays the embedded view out every frame. The callback lives on the view's
   * props so `onDropViewInstance` can cancel it (it reschedules itself forever)
   * and so the attach-to-window retry cannot start a second loop. */
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
    // 0 is RN's "unset" value, not a size: `ReactPropGroup` calls this setter
    // back with `defaultDouble` (0.0) when a dimension is REMOVED from the style.
    // Kept as a size it would pin the paywall to a 0px box, so it maps to null
    // and `resolveChildSize` falls back to the measured size.
    //
    // Unreachable from `<PLYPresentationView />`, which passes `style={{ flex }}`
    // only — reached solely by rendering the native component directly.
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
    // A view that unmounts without ever dismissing would otherwise leak its map
    // entries forever — only the dismiss paths purged them before.
    val props = propsByView.remove(view)
    props?.layoutCallback?.let { Choreographer.getInstance().removeFrameCallback(it) }
    props?.requestId?.let {
      PurchaselyModule.evictPresentationRequest(it)
    }
    // A preload still running, or a build waiting for the attach, would build a
    // paywall for a view that is gone.
    props?.host?.let { cancelPendingBuild(it, props) }
    props?.host = null
  }

  companion object {
    const val COMMAND_CREATE = 1
  }
}
