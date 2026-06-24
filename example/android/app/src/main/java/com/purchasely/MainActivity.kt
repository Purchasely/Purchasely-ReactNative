package com.purchasely

import android.os.Bundle
import com.facebook.react.ReactActivity
import com.facebook.react.ReactActivityDelegate
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint.fabricEnabled
import com.facebook.react.defaults.DefaultReactActivityDelegate

class MainActivity : ReactActivity() {

  // Resolved once in onCreate() so the E2E flag is stable before super.onCreate() runs.
  private var isE2eMode = false

  override fun onCreate(savedInstanceState: Bundle?) {
    isE2eMode = intent?.getStringExtra("E2E_MODE") == "true"
    super.onCreate(savedInstanceState)
  }

  override fun getMainComponentName(): String = "example"

  override fun createReactActivityDelegate(): ReactActivityDelegate =
    object : DefaultReactActivityDelegate(this, mainComponentName, fabricEnabled) {
      // Pass e2eMode as an initial prop so the JS root component can switch
      // to the E2ETestRunner without needing a separate component name.
      override fun getLaunchOptions(): Bundle =
        Bundle().apply {
          putBoolean("e2eMode", isE2eMode)
          if (isE2eMode) {
            putString("phase", intent?.getStringExtra("E2E_PHASE") ?: "all")
          }
        }

      // In E2E mode: do NOT notify React Native when MainActivity loses focus
      // to a child Activity (e.g. PLYFlowActivity). Without this override,
      // onHostPause() suspends the Hermes timer queue, freezing all JS awaits
      // (sleep, waitFor, Promise.race) for the duration of the paywall display.
      override fun onPause() {
        if (!isE2eMode) {
          super.onPause()
        }
      }
    }
}
