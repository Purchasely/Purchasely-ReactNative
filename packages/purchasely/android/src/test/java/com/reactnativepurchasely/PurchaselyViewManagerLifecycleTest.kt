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
import io.mockk.coEvery
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.mockkStatic
import io.mockk.runs
import io.mockk.slot
import io.mockk.unmockkObject
import io.mockk.unmockkStatic
import io.mockk.verify
import io.purchasely.ext.presentation.PLYPresentation
import io.purchasely.ext.presentation.PLYPresentationBase
import io.purchasely.ext.presentation.PLYPresentationOutcome
import io.purchasely.ext.presentation.PLYPurchaseResult
import io.purchasely.ext.presentation.preload
import io.purchasely.views.presentation.PLYPresentationView
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
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

    private val sdkView = mockk<PLYPresentationView>(relaxed = true) {
        every { parent } returns null
        // A relaxed View answers any id lookup of the window decor otherwise.
        every { findViewById<View>(any()) } returns null
    }
    private val presentation = mockk<PLYPresentation>(relaxed = true) {
        every { buildView(any(), any()) } returns sdkView
    }
    private val preloadStarted = CountDownLatch(1)

    @Before
    fun setUp() {
        controller = Robolectric.buildActivity(FragmentActivity::class.java).setup()
        activity = controller.get()
        val reactContext = mock<ReactApplicationContext> { on { currentActivity } doReturn activity }
        manager = PurchaselyViewManager(reactContext)
        mockkObject(PurchaselyModule)
        every { PurchaselyModule.loadedPresentation(REQUEST_ID) } returns presentation
        mockkStatic(PRELOAD_FILE)
        coEvery { any<PLYPresentationBase.Prepared>().preload() } coAnswers {
            preloadStarted.countDown()
            presentation
        }
    }

    @After
    fun tearDown() {
        unmockkStatic(PRELOAD_FILE)
        unmockkObject(PurchaselyModule)
    }

    // Regression: a view mounted then unmounted in the same main-thread task (a
    // banner mounted at cold start) crashed on the next Looper pass or pause.
    @Test
    fun `a view dropped right after its create loads nothing and does not crash`() {
        val root = mountedRoot()
        manager.setPlacementId(root, PLACEMENT_ID)

        create(root)
        (root.parent as ViewGroup).removeView(root)
        manager.onDropViewInstance(root)
        shadowOf(Looper.getMainLooper()).idle()
        controller.pause()

        assertFalse(preloadStarted.await(PRELOAD_WAIT_MS, TimeUnit.MILLISECONDS))
    }

    // An RN `<Modal>` is a Dialog window: a container looked up by id in the
    // Activity window is not found there, and the app crashed at every mount.
    @Test
    fun `a view in another window than the activity gets its paywall`() {
        val dialog = Dialog(activity)
        val root = newRoot()
        dialog.setContentView(root)
        dialog.show()
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(root.isAttachedToWindow)
        manager.setRequestId(root, REQUEST_ID)

        create(root)

        verify(exactly = 1) { presentation.buildView(activity, any()) }
        manager.onDropViewInstance(root)
    }

    // The SDK view takes its outcome callback from a global request when it
    // attaches. A view built while detached lets the next build replace that
    // request, and its outcome goes to another paywall.
    @Test
    fun `a preloaded paywall is built and added only once its view is attached`() {
        val root = newRoot()
        manager.setRequestId(root, REQUEST_ID)

        create(root)
        verify(exactly = 0) { presentation.buildView(any(), any()) }

        activity.addContentView(root, FrameLayout.LayoutParams(100, 100))
        verify(exactly = 1) { presentation.buildView(any(), any()) }
        assertSame(sdkView, (root.getChildAt(0) as ViewGroup).getChildAt(0))
        manager.onDropViewInstance(root)
    }

    @Test
    fun `a view dropped before its first attach never builds its paywall`() {
        val root = newRoot()
        manager.setRequestId(root, REQUEST_ID)
        create(root)

        manager.onDropViewInstance(root)
        activity.addContentView(root, FrameLayout.LayoutParams(100, 100))

        verify(exactly = 0) { presentation.buildView(any(), any()) }
    }

    // MOB-652: an empty builder made the SDK load the app default screen (ply_default).
    @Test
    fun `a view with no preloaded entry and no placement or screen loads nothing`() {
        every { PurchaselyModule.loadedPresentation(STALE_REQUEST_ID) } returns null
        // A spy: the real builder runs, and the call is recorded. No looper idle here:
        // the frame callback of a mounted view posts itself again on every frame.
        mockkObject(PLYPresentationBase.Companion)
        try {
            val root = mountedRoot()
            manager.setRequestId(root, STALE_REQUEST_ID)

            create(root)

            verify(exactly = 0) { PLYPresentationBase.builder() }
            verify(exactly = 0) { presentation.buildView(any(), any()) }
            manager.onDropViewInstance(root)
        } finally {
            unmockkObject(PLYPresentationBase.Companion)
        }
    }

    @Test
    fun `a second create command builds no second paywall`() {
        val root = mountedRoot()
        manager.setRequestId(root, REQUEST_ID)

        create(root)
        create(root)

        verify(exactly = 1) { presentation.buildView(any(), any()) }
        assertEquals(1, root.childCount)
        manager.onDropViewInstance(root)
    }

    // A rebuild removes the SDK view, and the SDK view sends its outcome when it
    // leaves the window: JS got "CANCELLED" for a paywall that stayed on screen,
    // and the real outcome was dropped.
    @Test
    fun `an activity configuration change keeps the paywall and its outcome`() {
        val root = mountedRoot()
        manager.setRequestId(root, REQUEST_ID)
        val sdkCallback = slot<(PLYPresentationOutcome) -> Unit>()
        every { presentation.buildView(any(), capture(sdkCallback)) } returns sdkView
        every { PurchaselyModule.emitPresentationDismissed(any(), any(), any()) } just runs
        create(root)
        val host = root.getChildAt(0) as ViewGroup
        // Stands for PLYPresentationView.onDetachedFromWindow, which a mock does not run.
        host.setOnHierarchyChangeListener(object : ViewGroup.OnHierarchyChangeListener {
            override fun onChildViewAdded(parent: View, child: View) {}
            override fun onChildViewRemoved(parent: View, child: View) = sdkCallback.captured(PLYPresentationOutcome())
        })

        activity.onConfigurationChanged(Configuration(activity.resources.configuration))

        verify(exactly = 1) { presentation.buildView(any(), any()) }
        assertSame(sdkView, host.getChildAt(0))
        verify(exactly = 0) { PurchaselyModule.emitPresentationDismissed(any(), any(), any()) }

        val purchased = PLYPresentationOutcome(purchaseResult = PLYPurchaseResult.PURCHASED)
        sdkCallback.captured(purchased)
        verify(exactly = 1) { PurchaselyModule.emitPresentationDismissed(any(), REQUEST_ID, purchased) }
        manager.onDropViewInstance(root)
    }

    private fun create(root: FrameLayout) =
        manager.receiveCommand(root, PurchaselyViewManager.COMMAND_CREATE.toString(), JavaOnlyArray.of(root.id))

    private fun newRoot(): FrameLayout = FrameLayout(activity).apply { id = View.generateViewId() }

    private fun mountedRoot(): FrameLayout {
        val root = newRoot()
        activity.addContentView(root, FrameLayout.LayoutParams(100, 100))
        return root
    }

    private companion object {
        const val REQUEST_ID = "request-1"
        const val STALE_REQUEST_ID = "request-stale"
        const val PLACEMENT_ID = "placement-1"
        const val PRELOAD_FILE = "io.purchasely.ext.presentation.PLYPresentationDslKt"
        // The preload runs on Dispatchers.Default: the wait bounds the check that it never starts.
        const val PRELOAD_WAIT_MS = 300L
    }
}
