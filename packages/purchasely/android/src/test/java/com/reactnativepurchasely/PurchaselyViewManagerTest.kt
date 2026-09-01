package com.reactnativepurchasely

import android.widget.FrameLayout
import com.facebook.react.bridge.ReactApplicationContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.junit.MockitoJUnitRunner

/**
 * Unit tests for PurchaselyViewManager.
 *
 * React Native reuses ONE manager instance for every `<PLYPresentationView />`,
 * so anything the manager stores must be keyed by view.
 */
@RunWith(MockitoJUnitRunner::class)
class PurchaselyViewManagerTest {

    private lateinit var manager: PurchaselyViewManager

    @Before
    fun setUp() {
        manager = PurchaselyViewManager(mock(ReactApplicationContext::class.java))
    }

    @Test
    fun `manager name should be PurchaselyView`() {
        assertEquals("PurchaselyView", manager.name)
    }

    // Regression: `propWidth` / `propHeight` used to live on the manager itself,
    // so two banners mounted at once (a home one and an in-article one) forced
    // each other's dimensions and one of them lost its button.
    @Test
    fun `two mounted views keep their own width and height`() {
        val first = mock(FrameLayout::class.java)
        val second = mock(FrameLayout::class.java)

        manager.setStyle(first, 0, 320.0)
        manager.setStyle(first, 1, 140.0)
        manager.setStyle(second, 0, 200.0)
        manager.setStyle(second, 1, 90.0)

        assertEquals(320, manager.propsFor(first).width)
        assertEquals(140, manager.propsFor(first).height)
        assertEquals(200, manager.propsFor(second).width)
        assertEquals(90, manager.propsFor(second).height)
    }

    @Test
    fun `a non finite dimension is ignored rather than collapsing the view to zero`() {
        val view = mock(FrameLayout::class.java)

        manager.setStyle(view, 0, Double.NaN)
        manager.setStyle(view, 1, -1.0)

        assertNull(manager.propsFor(view).width)
        assertNull(manager.propsFor(view).height)
    }

    @Test
    fun `child size falls back to the measured size when no prop is set`() {
        assertEquals(48, manager.resolveChildSize(null, 48, 200))
        assertEquals(200, manager.resolveChildSize(null, 0, 200))
        assertEquals(0, manager.resolveChildSize(null, 0, 0))
        assertEquals(140, manager.resolveChildSize(140, 48, 200))
    }
}
