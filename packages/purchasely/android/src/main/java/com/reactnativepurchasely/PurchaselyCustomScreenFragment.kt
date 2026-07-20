package com.reactnativepurchasely

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import com.facebook.react.ReactApplication
import com.facebook.react.ReactRootView
import com.facebook.react.interfaces.fabric.ReactSurface
import com.facebook.react.internal.featureflags.ReactNativeFeatureFlags

/** Hosts an app-registered React component inside a Purchasely Custom Screen flow step. */
class PurchaselyCustomScreenFragment : Fragment() {
  private var reactSurface: ReactSurface? = null
  private var reactRootView: ReactRootView? = null

  override fun onCreateView(
    inflater: LayoutInflater,
    container: ViewGroup?,
    savedInstanceState: Bundle?
  ): View {
    val context = requireContext()
    val hostView = FrameLayout(context)
    try {
      val application = requireActivity().application as ReactApplication
      val componentName = requireArguments().getString(ARG_COMPONENT_NAME)
        ?: error("Missing Custom Screen component name")
      val initialProps = Bundle().apply {
        putBundle(
          "presentation",
          requireArguments().getBundle(ARG_PRESENTATION) ?: Bundle()
        )
      }
      if (ReactNativeFeatureFlags.enableBridgelessArchitecture()) {
        val reactHost = application.reactHost
          ?: error("Bridgeless React Native application has no ReactHost")
        reactSurface = reactHost.createSurface(context, componentName, initialProps).also { surface ->
          surface.start()
          surface.view?.let { hostView.addView(it, matchParentLayoutParams()) }
            ?: Log.w(TAG, "React surface did not create a view for $componentName")
        }
      } else {
        reactRootView = ReactRootView(context).also { rootView ->
          rootView.startReactApplication(
            application.reactNativeHost.reactInstanceManager,
            componentName,
            initialProps
          )
          hostView.addView(rootView, matchParentLayoutParams())
        }
      }
    } catch (error: Throwable) {
      Log.w(TAG, "Unable to mount the Purchasely Custom Screen React component", error)
    }
    return hostView
  }

  override fun onDestroyView() {
    reactSurface?.stop()
    reactSurface = null
    reactRootView?.unmountReactApplication()
    reactRootView = null
    super.onDestroyView()
  }

  override fun onDestroy() {
    if (isRemoving || parentFragment?.isRemoving == true || activity?.isFinishing == true) {
      arguments?.getString(ARG_CUSTOM_SCREEN_ID)?.let {
        PurchaselyModule.releaseCustomScreen(it)
      }
    }
    super.onDestroy()
  }

  private fun matchParentLayoutParams() = FrameLayout.LayoutParams(
    ViewGroup.LayoutParams.MATCH_PARENT,
    ViewGroup.LayoutParams.MATCH_PARENT
  )

  companion object {
    private const val TAG = "PurchaselyCustomScreen"
    private const val ARG_COMPONENT_NAME = "componentName"
    private const val ARG_CUSTOM_SCREEN_ID = "customScreenId"
    private const val ARG_PRESENTATION = "presentation"

    fun newInstance(
      componentName: String,
      customScreenId: String,
      presentation: Bundle
    ) = PurchaselyCustomScreenFragment().apply {
      arguments = Bundle().apply {
        putString(ARG_COMPONENT_NAME, componentName)
        putString(ARG_CUSTOM_SCREEN_ID, customScreenId)
        putBundle(ARG_PRESENTATION, presentation)
      }
    }
  }
}
