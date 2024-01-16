package com.reactnativepurchasely

import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.annotations.ReactPropGroup
import io.purchasely.ext.PLYPresentationViewProperties
import io.purchasely.ext.Purchasely
import io.purchasely.views.presentation.PLYPresentationView

class NativeViewManager() : SimpleViewManager<LinearLayout>() {
  override fun getName(): String = "NativeViewManager"
  override fun createViewInstance(context: ThemedReactContext): LinearLayout {
    val layout = LinearLayout(context)

    layout.orientation = LinearLayout.VERTICAL

    layout.layoutParams = ViewGroup.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT,
      ViewGroup.LayoutParams.MATCH_PARENT
    )

    return layout
  }

  @ReactProp(name = "presentationId")
  fun setPresentationId(view: LinearLayout, presentationId: String?) {
    val presentationText = TextView(view.context)
    presentationText.text = presentationId
    view.addView(presentationText)

    val presentation = Purchasely.presentationView(
      context = view.context,
      properties = PLYPresentationViewProperties(presentationId = presentationId)
    )

    if(presentation != null) {
      presentation.layoutParams = ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT
      )

      view.addView(presentation)
    }
  }

  @ReactProp(name = "placementId")
  fun setPlacementId(view: LinearLayout, placementId: String?) {
    val presentationText = TextView(view.context)
    presentationText.text = placementId
    view.addView(presentationText)

    val presentation = Purchasely.presentationView(
      context = view.context,
      properties = PLYPresentationViewProperties(placementId = placementId)
    )

    if(presentation != null) {
      view.addView(presentation)
    }
  }

//  @ReactPropGroup(names = ["width", "height"], customType = "Style")
//  fun setStyle(view: LinearLayout, index: Int, value: Int) {
//    if (index == 0) propWidth = value
//    if (index == 1) propHeight = value
//  }
}
