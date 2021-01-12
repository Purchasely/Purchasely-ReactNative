package com.reactnativepurchasely

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import io.purchasely.ext.Purchasely

class PLYProductActivity : AppCompatActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_ply_product_activity)

    val productId = intent.extras?.getString("productId") ?: let {
      supportFinishAfterTransition()
      return
    }
    val presentationId = intent.extras?.getString("presentationId")

    val fragment: Fragment = Purchasely.productFragment(
      productId,
      presentationId,
    null)

    supportFragmentManager
      .beginTransaction()
      .replace(R.id.fragmentContainer, fragment)
      .commit()
  }

}
