package com.reactnativepurchasely

import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.ReactApplicationContext
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.doReturn
import org.mockito.kotlin.mock
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ActivityController

/**
 * Fragment lifecycle of `<PLYPresentationView />` against a real FragmentManager.
 */
@RunWith(RobolectricTestRunner::class)
class PurchaselyViewManagerFragmentTest {

    private lateinit var controller: ActivityController<FragmentActivity>
    private lateinit var activity: FragmentActivity
    private lateinit var manager: PurchaselyViewManager

    @Before
    fun setUp() {
        controller = Robolectric.buildActivity(FragmentActivity::class.java).setup()
        activity = controller.get()
        val reactContext = mock<ReactApplicationContext> { on { currentActivity } doReturn activity }
        manager = PurchaselyViewManager(reactContext)
    }

    // Regression: a view mounted then unmounted in the same main-thread task (a
    // banner mounted at cold start) left its queued fragment behind, and the
    // FragmentManager threw "No view found for id" when it ran the transaction.
    @Test
    fun `a view dropped before its fragment commit runs leaves no fragment and does not crash`() {
        val root = mountedRoot()

        manager.receiveCommand(root, PurchaselyViewManager.COMMAND_CREATE.toString(), JavaOnlyArray.of(root.id))
        (root.parent as ViewGroup).removeView(root)
        manager.onDropViewInstance(root)
        shadowOf(Looper.getMainLooper()).idle()

        assertTrue(activity.supportFragmentManager.fragments.isEmpty())
    }

    // The same orphaned transaction, flushed by the activity pause instead.
    @Test
    fun `a view dropped before its fragment commit runs does not crash the activity pause`() {
        val root = mountedRoot()

        manager.receiveCommand(root, PurchaselyViewManager.COMMAND_CREATE.toString(), JavaOnlyArray.of(root.id))
        (root.parent as ViewGroup).removeView(root)
        manager.onDropViewInstance(root)
        controller.pause()

        assertTrue(activity.supportFragmentManager.fragments.isEmpty())
    }

    private fun mountedRoot(): FrameLayout {
        val root = FrameLayout(activity).apply { id = View.generateViewId() }
        activity.addContentView(root, FrameLayout.LayoutParams(100, 100))
        return root
    }
}
