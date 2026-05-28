package com.reactnativepurchasely.v6

import android.app.Activity
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import com.reactnativepurchasely.PurchaselyModule
import io.purchasely.ext.PLYInterceptorInfo
import io.purchasely.ext.PLYInterceptResult
import io.purchasely.ext.PLYLogger
import io.purchasely.ext.Purchasely
import io.purchasely.ext.presentation.PLYCloseReason
import io.purchasely.ext.presentation.PLYPresentation
import io.purchasely.ext.presentation.PLYPresentationAction
import io.purchasely.ext.presentation.PLYPresentationBase
import io.purchasely.ext.presentation.PLYPresentationOutcome
import io.purchasely.ext.presentation.PLYPurchaseResult
import io.purchasely.ext.presentation.display
import io.purchasely.ext.presentation.preload
import io.purchasely.models.PLYError
import io.purchasely.views.presentation.models.PLYTransition
import io.purchasely.views.presentation.models.PLYTransitionType
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Bridge implementation for the v6 cross-platform contract.
 *
 * The methods exposed here are called from the JS side as
 * `NativeModules.Purchasely.v6Preload(...)`, etc. Lifecycle events are emitted
 * over the existing `RCTDeviceEventEmitter` using the
 * `PURCHASELY_V6_*` event names.
 *
 * Implemented as a static helper rather than a separate `ReactContextBaseJavaModule`
 * so it can sit on the same `Purchasely` native module name as the legacy bridge.
 *
 * Contract: reports/v6-presentation-comparison-v3-claude/BRIDGE-CONTRACT.md
 */
object PurchaselyV6Bridge {

    private const val EVENT_LOADED = "PURCHASELY_V6_LOADED"
    private const val EVENT_PRESENTED = "PURCHASELY_V6_PRESENTED"
    private const val EVENT_CLOSE_REQUESTED = "PURCHASELY_V6_CLOSE_REQUESTED"
    private const val EVENT_DISMISSED = "PURCHASELY_V6_DISMISSED"
    private const val EVENT_ACTION_INTERCEPTED = "PURCHASELY_V6_ACTION_INTERCEPTED"

    /**
     * Active presentation requests, keyed by the JS-supplied requestId. Lets
     * `v6Close` / `v6Back` find the right `Prepared` to act on.
     */
    private val activeRequests = ConcurrentHashMap<String, PLYPresentationBase.Prepared>()

    /**
     * Pending interceptor callbacks. The bridge resolves the suspending block
     * once JS calls back via [completeInterceptor].
     */
    private val pendingInterceptors =
        ConcurrentHashMap<String, CompletableDeferred<PLYInterceptResult>>()

    /**
     * Build a [PLYPresentationBase.Prepared] from the JS payload.
     */
    private fun buildPrepared(payload: ReadableMap?): PLYPresentationBase.Prepared {
        val builder = PLYPresentationBase.builder()
        payload?.let { p ->
            if (p.hasKey("placementId") && !p.isNull("placementId")) {
                builder.placementId(p.getString("placementId")!!)
            }
            if (p.hasKey("presentationId") && !p.isNull("presentationId")) {
                // The JS `screenId` is forwarded as the legacy native key `presentationId`.
                builder.screenId(p.getString("presentationId")!!)
            }
            if (p.hasKey("contentId") && !p.isNull("contentId")) {
                builder.contentId(p.getString("contentId"))
            }
            if (p.hasKey("displayCloseButton") && !p.isNull("displayCloseButton")) {
                builder.displayCloseButton(p.getBoolean("displayCloseButton"))
            }
            if (p.hasKey("displayBackButton") && !p.isNull("displayBackButton")) {
                builder.displayBackButton(p.getBoolean("displayBackButton"))
            }
            if (p.hasKey("backgroundColor") && !p.isNull("backgroundColor")) {
                runCatching {
                    val color = android.graphics.Color.parseColor(p.getString("backgroundColor"))
                    builder.backgroundColor(color)
                }.onFailure {
                    PLYLogger.w("[v6] invalid backgroundColor: ${p.getString("backgroundColor")}")
                }
            }
            if (p.hasKey("progressColor") && !p.isNull("progressColor")) {
                runCatching {
                    val color = android.graphics.Color.parseColor(p.getString("progressColor"))
                    builder.progressColor(color)
                }.onFailure {
                    PLYLogger.w("[v6] invalid progressColor: ${p.getString("progressColor")}")
                }
            }
        }
        return builder.build()
    }

    /**
     * Convert a [PLYPresentation] to a React-Native map. We expose the screenId
     * (mapped from the SDK `screenId`) and keep `id` as alias for compat.
     */
    private fun PLYPresentation.toV6Map(): WritableMap {
        val map = Arguments.createMap()
        map.putString("screenId", screenId)
        map.putString("id", screenId)
        placementId?.let { map.putString("placementId", it) }
        contentId?.let { map.putString("contentId", it) }
        // Audience / AB-test ids live in the request payload; expose what we have.
        runCatching { audienceId?.let { map.putString("audienceId", it) } }
        runCatching { abTestId?.let { map.putString("abTestId", it) } }
        runCatching { abTestVariantId?.let { map.putString("abTestVariantId", it) } }
        runCatching { language?.let { map.putString("language", it) } }
        runCatching { map.putInt("type", type.ordinal) }
        runCatching { height?.let { map.putInt("height", it) } }
        return map
    }

    private fun PLYError.toV6Map(): WritableMap {
        val map = Arguments.createMap()
        map.putString("message", message ?: "Unknown error")
        return map
    }

    private fun PLYCloseReason.toV6String(): String = when (this) {
        PLYCloseReason.BUTTON -> "button"
        PLYCloseReason.BACK_SYSTEM -> "backSystem"
        PLYCloseReason.PROGRAMMATIC -> "programmatic"
    }

    private fun PLYPurchaseResult.toOrdinal(): Int = when (this) {
        PLYPurchaseResult.PURCHASED -> 0
        PLYPurchaseResult.CANCELLED -> 1
        PLYPurchaseResult.RESTORED -> 2
    }

    private fun sendEvent(
        context: ReactContext?,
        eventName: String,
        params: WritableMap?
    ) {
        context
            ?.getJSModule(RCTDeviceEventEmitter::class.java)
            ?.emit(eventName, params)
    }

    private fun wireCallbacks(
        context: ReactContext?,
        requestId: String,
        prepared: PLYPresentationBase.Prepared
    ) {
        prepared.onPresented = { presentation, error ->
            val payload = Arguments.createMap()
            payload.putString("requestId", requestId)
            presentation?.let { payload.putMap("presentation", it.toV6Map()) }
            error?.let { payload.putMap("error", it.toV6Map()) }
            sendEvent(context, EVENT_PRESENTED, payload)
        }
        prepared.onCloseRequested = {
            val payload = Arguments.createMap()
            payload.putString("requestId", requestId)
            sendEvent(context, EVENT_CLOSE_REQUESTED, payload)
        }
        prepared.onDismissed = { outcome: PLYPresentationOutcome ->
            val payload = Arguments.createMap()
            payload.putString("requestId", requestId)
            outcome.presentation?.let { payload.putMap("presentation", it.toV6Map()) }
            outcome.purchaseResult?.let { payload.putInt("purchaseResult", it.toOrdinal()) }
            outcome.plan?.let {
                payload.putMap("plan", Arguments.makeNativeMap(
                    PurchaselyModule.transformPlanToMap(it).toMutableMap()
                ))
            }
            outcome.closeReason?.let { payload.putString("closeReason", it.toV6String()) }
            outcome.error?.let { payload.putMap("error", it.toV6Map()) }
            sendEvent(context, EVENT_DISMISSED, payload)
            activeRequests.remove(requestId)
        }
    }

    /**
     * v6 preload entry point. JS calls this with a requestId + builder payload.
     */
    @JvmStatic
    fun preload(
        reactContext: ReactApplicationContext,
        requestId: String,
        payload: ReadableMap?,
        promise: Promise
    ) {
        try {
            val prepared = buildPrepared(payload)
            activeRequests[requestId] = prepared
            wireCallbacks(reactContext, requestId, prepared)

            prepared.preload { loaded, error ->
                val map = Arguments.createMap()
                map.putString("requestId", requestId)
                loaded?.let { map.putMap("presentation", it.toV6Map()) }
                error?.let { map.putMap("error", it.toV6Map()) }
                sendEvent(reactContext, EVENT_LOADED, map)
            }
            promise.resolve(true)
        } catch (e: Throwable) {
            promise.reject("v6_preload_failure", e.message, e)
        }
    }

    /**
     * v6 display entry point. JS calls this with a requestId + builder payload
     * (+ optional transition).
     */
    @JvmStatic
    fun display(
        reactContext: ReactApplicationContext,
        requestId: String,
        payload: ReadableMap?,
        transitionMap: ReadableMap?,
        promise: Promise
    ) {
        try {
            val activity: Activity = reactContext.currentActivity
                ?: throw IllegalStateException("No current activity to host the presentation")

            val prepared = activeRequests[requestId] ?: buildPrepared(payload).also {
                activeRequests[requestId] = it
                wireCallbacks(reactContext, requestId, it)
            }

            val transition: PLYTransition? = transitionMap?.let { tm ->
                if (!tm.hasKey("type") || tm.isNull("type")) {
                    null
                } else {
                    val type = when (tm.getString("type")) {
                        "fullScreen" -> PLYTransitionType.FULLSCREEN
                        "push" -> PLYTransitionType.PUSH
                        "modal" -> PLYTransitionType.MODAL
                        "drawer" -> PLYTransitionType.DRAWER
                        "popin" -> PLYTransitionType.POPIN
                        // `inlinePaywall` not supported by PLYTransition — fall through.
                        else -> PLYTransitionType.FULLSCREEN
                    }
                    val heightPercentage =
                        if (tm.hasKey("heightPercentage") && !tm.isNull("heightPercentage")) {
                            tm.getDouble("heightPercentage").toFloat()
                        } else {
                            null
                        }
                    val dismissible =
                        if (tm.hasKey("dismissible") && !tm.isNull("dismissible")) {
                            tm.getBoolean("dismissible")
                        } else {
                            true
                        }
                    PLYTransition(
                        type = type,
                        heightPercentage = heightPercentage,
                        dismissible = dismissible
                    )
                }
            }

            // The SDK DSL extension exposes the callback-form of display(). The
            // outcome itself is already emitted to JS through `onDismissed` (wired in
            // `wireCallbacks`), so the local `callback` is a noop. We still pass an
            // outcome handler to ensure the SDK does not log a warning about a missing
            // callback.
            prepared.display(
                context = activity,
                transition = transition,
                presentation = null,
                callback = { /* dismissed event is sent via onDismissed */ }
            )

            promise.resolve(true)
        } catch (e: Throwable) {
            // Synthesize a dismissed event so the JS side resolves the display Promise.
            val payload = Arguments.createMap()
            payload.putString("requestId", requestId)
            payload.putMap("error", Arguments.createMap().apply {
                putString("message", e.message ?: "Display failed")
            })
            sendEvent(reactContext, EVENT_DISMISSED, payload)
            activeRequests.remove(requestId)
            promise.reject("v6_display_failure", e.message, e)
        }
    }

    @JvmStatic
    fun close(requestId: String) {
        activeRequests.remove(requestId)
        // Closing all screens is the closest match — the SDK v6 does not yet
        // expose a per-request close.
        Purchasely.closeAllScreens()
    }

    @JvmStatic
    fun back(requestId: String) {
        // No public `back()` on the Java façade — surface as a noop log.
        PLYLogger.w("[v6] back($requestId) is not yet bridged on Android")
    }

    /** Register an interceptor for a given action kind. */
    @JvmStatic
    fun registerInterceptor(reactContext: ReactApplicationContext, kind: String) {
        val actionType: Class<out PLYPresentationAction> = when (kind) {
            "close" -> PLYPresentationAction.Close::class.java
            "closeAll" -> PLYPresentationAction.CloseAll::class.java
            "login" -> PLYPresentationAction.Login::class.java
            "navigate" -> PLYPresentationAction.Navigate::class.java
            "purchase" -> PLYPresentationAction.Purchase::class.java
            "restore" -> PLYPresentationAction.Restore::class.java
            "openPresentation" -> PLYPresentationAction.OpenPresentation::class.java
            "openPlacement" -> PLYPresentationAction.OpenPlacement::class.java
            "promoCode" -> PLYPresentationAction.PromoCode::class.java
            "webCheckout" -> PLYPresentationAction.WebCheckout::class.java
            else -> {
                PLYLogger.w("[v6] unknown interceptor kind: $kind")
                return
            }
        }

        Purchasely.interceptAction(actionType) { info, action, complete ->
            val callbackId = UUID.randomUUID().toString()
            val deferred = CompletableDeferred<PLYInterceptResult>()
            pendingInterceptors[callbackId] = deferred

            val payload = Arguments.createMap()
            payload.putString("requestId", "")
            payload.putString("callbackId", callbackId)
            payload.putString("kind", kind)
            payload.putMap("info", info.toV6Map())
            payload.putMap("payload", action.toV6Payload())
            sendEvent(reactContext, EVENT_ACTION_INTERCEPTED, payload)

            CoroutineScope(Dispatchers.Main).launch {
                val result = runCatching { deferred.await() }
                    .getOrDefault(PLYInterceptResult.NOT_HANDLED)
                complete(result)
            }
        }
    }

    @JvmStatic
    fun unregisterInterceptor(kind: String) {
        val actionType: Class<out PLYPresentationAction>? = when (kind) {
            "close" -> PLYPresentationAction.Close::class.java
            "closeAll" -> PLYPresentationAction.CloseAll::class.java
            "login" -> PLYPresentationAction.Login::class.java
            "navigate" -> PLYPresentationAction.Navigate::class.java
            "purchase" -> PLYPresentationAction.Purchase::class.java
            "restore" -> PLYPresentationAction.Restore::class.java
            "openPresentation" -> PLYPresentationAction.OpenPresentation::class.java
            "openPlacement" -> PLYPresentationAction.OpenPlacement::class.java
            "promoCode" -> PLYPresentationAction.PromoCode::class.java
            "webCheckout" -> PLYPresentationAction.WebCheckout::class.java
            else -> null
        }
        if (actionType == null) {
            PLYLogger.w("[v6] unknown interceptor kind: $kind")
            return
        }
        runCatching {
            Purchasely.removeActionInterceptor(actionType)
        }.onFailure {
            PLYLogger.w("[v6] removeActionInterceptor($kind) failed: ${it.message}")
        }
    }

    @JvmStatic
    fun completeInterceptor(callbackId: String, result: String) {
        val deferred = pendingInterceptors.remove(callbackId) ?: return
        deferred.complete(
            when (result) {
                "success" -> PLYInterceptResult.SUCCESS
                "failed" -> PLYInterceptResult.FAILED
                else -> PLYInterceptResult.NOT_HANDLED
            }
        )
    }

    @JvmStatic
    fun applyStartOptions(options: ReadableMap) {
        if (options.hasKey("allowDeeplink") && !options.isNull("allowDeeplink")) {
            Purchasely.readyToOpenDeeplink = options.getBoolean("allowDeeplink")
        }
        if (options.hasKey("allowCampaigns") && !options.isNull("allowCampaigns")) {
            // No direct setter for "disallowCampaigns" — leverage the privacy API.
            // If the host opts out, we record it through the consent manager.
            if (!options.getBoolean("allowCampaigns")) {
                runCatching {
                    Purchasely.revokeDataProcessingConsent(
                        setOf(
                            io.purchasely.ext.PLYDataProcessingPurpose.Campaigns
                        )
                    )
                }.onFailure {
                    PLYLogger.w("[v6] allowCampaigns(false) could not be honored: ${it.message}")
                }
            }
        }
    }

    private fun PLYInterceptorInfo.toV6Map(): WritableMap {
        val map = Arguments.createMap()
        contentId?.let { map.putString("contentId", it) }
        presentation?.let { map.putMap("presentation", it.toV6Map()) }
        return map
    }

    private fun PLYPresentationAction.toV6Payload(): WritableMap {
        val payload = Arguments.createMap()
        when (this) {
            is PLYPresentationAction.Navigate -> {
                payload.putString("url", url.toString())
                title?.let { payload.putString("title", it) }
            }
            is PLYPresentationAction.Purchase -> {
                payload.putMap(
                    "plan",
                    Arguments.makeNativeMap(
                        PurchaselyModule.transformPlanToMap(plan).toMutableMap()
                    )
                )
                offer?.let {
                    val offerMap = Arguments.createMap()
                    it.vendorId?.let { v -> offerMap.putString("vendorId", v) }
                    it.storeOfferId?.let { v -> offerMap.putString("storeOfferId", v) }
                    payload.putMap("offer", offerMap)
                }
                subscriptionOffer?.let { so ->
                    val soMap = Arguments.createMap()
                    soMap.putString("subscriptionId", so.subscriptionId)
                    so.basePlanId?.let { soMap.putString("basePlanId", it) }
                    so.offerToken?.let { soMap.putString("offerToken", it) }
                    so.offerId?.let { soMap.putString("offerId", it) }
                    payload.putMap("subscriptionOffer", soMap)
                }
            }
            is PLYPresentationAction.Close -> {
                payload.putString("closeReason", closeReason.toV6String())
            }
            is PLYPresentationAction.CloseAll -> {
                payload.putString("closeReason", closeReason.toV6String())
            }
            is PLYPresentationAction.OpenPresentation -> {
                payload.putString("presentationId", presentationId)
            }
            is PLYPresentationAction.OpenPlacement -> {
                payload.putString("placementId", placementId)
            }
            is PLYPresentationAction.WebCheckout -> {
                payload.putString("url", url.toString())
                payload.putString("clientReferenceId", clientReferenceId)
                payload.putString("queryParameterKey", queryParameterKey)
                payload.putString(
                    "webCheckoutProvider",
                    webCheckoutProvider.name.lowercase()
                )
            }
            else -> {
                // login, restore, promoCode → no extra payload.
            }
        }
        return payload
    }
}
