package com.reactnativepurchasely

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

/**
 * Stub activity kept solely to honour the AndroidManifest declaration produced
 * by v5. The v6 React Native bridge no longer hosts paywalls in this Activity —
 * presentations flow through `Purchasely.builder(...).display()` (which delegates
 * to the SDK's own activity).
 *
 * The companion `newIntent(...)` helper is preserved so any v5 caller that still
 * references it compiles but its return value points to this stub, which
 * immediately finishes — surfacing the missing v6 migration in development.
 */
class PLYProductActivity : AppCompatActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    finish()
  }

  companion object {
    @JvmStatic
    fun newIntent(
      activity: Activity?,
      @Suppress("UNUSED_PARAMETER") placementId: String? = null,
      @Suppress("UNUSED_PARAMETER") presentationId: String? = null,
      @Suppress("UNUSED_PARAMETER") productId: String? = null,
      @Suppress("UNUSED_PARAMETER") planId: String? = null,
      @Suppress("UNUSED_PARAMETER") contentId: String? = null,
      @Suppress("UNUSED_PARAMETER") isFullScreen: Boolean = false,
      @Suppress("UNUSED_PARAMETER") backgroundColor: String? = null
    ): Intent = Intent(activity, PLYProductActivity::class.java)
  }
}
