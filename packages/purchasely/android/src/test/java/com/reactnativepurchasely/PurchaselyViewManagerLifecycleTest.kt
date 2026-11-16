package com.reactnativepurchasely

import android.app.Dialog
import android.content.res.Configuration
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.ReactApplicationContext
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import io.purchasely.ext.presentation.PLYPresentation
import org.junit.After
import org.junit.Assert.assertEquals
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
 * Lifecycle of `<PLYPresentationView />` against a real Activity and main Looper.
 */
@RunWith(RobolectricTestRunner::class)
class PurchaselyViewManagerLifecycleTest {

    private lateinit var controller: ActivityController<FragmentActivity>
    private lateinit var activity: FragmentActivity
    private lateinit var manager: PurchaselyViewManager

    @Before
    fun setUp() {
        controller = Robolectric.buildActivity(FragmentActivity::class.java).setup()
        activity = controller.get()
        val reactContext = mock<ReactApplicationContext> { on { currentActivity } doReturn activity }
        manager = PurchaselyViewManager(reactContext)
        mockkObject(PurchaselyModule)
        every { PurchaselyModule.loadedPresentation(REQUEST_ID) } returns presentation
    }

    @After
    fun tearDown() {
        unmockkObject(PurchaselyModule)
    }

    private val presentation = mockk<PLYPresentation>(relaxed = true) {
        every { buildView(any(), any()) } returns null
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

    // An RN `<Modal>` is a Dialog window: a container looked up by id in the
    // Activity window is not found there, and the app crashed at every mount.
    @Test
    fun `a view in another window than the activity gets its paywall host`() {
        val dialog = Dialog(activity)
        val root = FrameLayout(activity).apply { id = View.generateViewId() }
        dialog.setContentView(root)
        dialog.show()
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(root.isAttachedToWindow)

        manager.receiveCommand(root, PurchaselyViewManager.COMMAND_CREATE.toString(), JavaOnlyArray.of(root.id))
        // Not `idle()`: the per-frame layout loop of a mounted view never lets it end.
        activity.supportFragmentManager.executePendingTransactions()

        assertEquals(1, root.childCount)
        manager.onDropViewInstance(root)
    }

    // The SDK view takes its outcome callback from a global request when it
    // attaches. A view built while detached lets the next build replace that
    // request, and its outcome goes to another paywall.
    @Test
    fun `a preloaded paywall is built only once its view is attached`() {
        val root = FrameLayout(activity).apply { id = View.generateViewId() }
        manager.setRequestId(root, REQUEST_ID)

        manager.receiveCommand(root, PurchaselyViewManager.COMMAND_CREATE.toString(), JavaOnlyArray.of(root.id))
        verify(exactly = 0) { presentation.buildView(any(), any()) }

        activity.addContentView(root, FrameLayout.LayoutParams(100, 100))
        verify(exactly = 1) { presentation.buildView(any(), any()) }
        manager.onDropViewInstance(root)
    }

    @Test
    fun `a view dropped before its first attach never builds its paywall`() {
        val root = FrameLayout(activity).apply { id = View.generateViewId() }
        manager.setRequestId(root, REQUEST_ID)
        manager.receiveCommand(root, PurchaselyViewManager.COMMAND_CREATE.toString(), JavaOnlyArray.of(root.id))

        manager.onDropViewInstance(root)
        activity.addContentView(root, FrameLayout.LayoutParams(100, 100))

        verify(exactly = 0) { presentation.buildView(any(), any()) }
    }

    @Test
    fun `a configuration change rebuilds the paywall`() {
        val root = mountedRoot()
        manager.setRequestId(root, REQUEST_ID)
        manager.receiveCommand(root, PurchaselyViewManager.COMMAND_CREATE.toString(), JavaOnlyArray.of(root.id))

        root.getChildAt(0).dispatchConfigurationChanged(Configuration())

        verify(exactly = 2) { presentation.buildView(any(), any()) }
        manager.onDropViewInstance(root)
    }

    private fun mountedRoot(): FrameLayout {
        val root = FrameLayout(activity).apply { id = View.generateViewId() }
        activity.addContentView(root, FrameLayout.LayoutParams(100, 100))
        return root
    }

    private companion object {
        const val REQUEST_ID = "request-1"
    }
}
