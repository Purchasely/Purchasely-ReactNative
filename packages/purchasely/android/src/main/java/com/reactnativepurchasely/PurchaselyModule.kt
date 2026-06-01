package com.reactnativepurchasely

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.fragment.app.FragmentActivity
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import io.purchasely.billing.Store
import io.purchasely.ext.*
import io.purchasely.ext.EventListener
import io.purchasely.ext.presentation.PLYPresentation
import io.purchasely.ext.presentation.PLYPresentationType
import io.purchasely.models.PLYPlan
import io.purchasely.models.PLYPresentationPlan
import io.purchasely.storage.userData.PLYUserAttributeSource
import io.purchasely.storage.userData.PLYUserAttributeType
import io.purchasely.views.presentation.PLYThemeMode
import io.purchasely.ext.PLYDataProcessingLegalBasis
import io.purchasely.ext.PLYDataProcessingPurpose
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.text.SimpleDateFormat
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap
// v6 cross-platform bridge (merged into this single module)
import android.app.Activity
import io.purchasely.ext.presentation.PLYCloseReason
import io.purchasely.ext.presentation.PLYPresentationAction
import io.purchasely.ext.presentation.PLYPresentationBase
import io.purchasely.ext.presentation.PLYPresentationOutcome
import io.purchasely.ext.presentation.PLYPurchaseResult
import io.purchasely.ext.presentation.display
import io.purchasely.ext.presentation.preload
import io.purchasely.models.PLYError
import io.purchasely.views.presentation.models.PLYTransition
import io.purchasely.views.presentation.models.PLYTransitionType
import java.util.concurrent.ConcurrentHashMap

class PurchaselyModule internal constructor(context: ReactApplicationContext) : ReactContextBaseJavaModule(context) {

  private val eventListener: EventListener = object: EventListener {
    override fun onEvent(event: PLYEvent) {
      val map = mapOf(
        Pair("name", event.name),
        Pair("properties", event.properties.toMap())
      )
      sendEvent(reactApplicationContext, "PURCHASELY_EVENTS", Arguments.makeNativeMap(map))
    }
  }

  private val purchaseListener: PurchaseListener = object: PurchaseListener {
    override fun onPurchaseStateChanged(state: State) {
      if(state is State.PurchaseComplete || state is State.RestorationComplete) {
        sendEvent(reactApplicationContext, "PURCHASE_LISTENER", null)
      }
    }
  }

  private val userAttributeListener: UserAttributeListener = object: UserAttributeListener {
    override fun onUserAttributeSet(key: String, type: PLYUserAttributeType, value: Any, source: PLYUserAttributeSource) {
      val params = Arguments.makeNativeMap(mapOf(
        Pair("key", key),
        Pair("type", type.ordinal),
        Pair("value", getUserAttributeValueForRN(value)),
        Pair("source", source.ordinal),
      ))
      sendEvent(reactApplicationContext, "USER_ATTRIBUTE_SET_LISTENER", params)
    }

    override fun onUserAttributeRemoved(key: String, source: PLYUserAttributeSource) {
      val params = Arguments.makeNativeMap(mapOf(
        Pair("key", key),
        Pair("source", source.ordinal)
      ))
      sendEvent(reactApplicationContext, "USER_ATTRIBUTE_REMOVED_LISTENER", params)
    }
  }

  override fun getName(): String {
    return "Purchasely"
  }

  val mutex = Mutex()

  override fun getConstants(): Map<String, Int> {
    val constants: MutableMap<String, Int> = HashMap()
    constants["logLevelDebug"] = LogLevel.DEBUG.ordinal
    constants["logLevelWarn"] = LogLevel.WARN.ordinal
    constants["logLevelInfo"] = LogLevel.INFO.ordinal
    constants["logLevelError"] = LogLevel.ERROR.ordinal
    @Suppress("DEPRECATION")
    constants["productResultPurchased"] = PLYProductViewResult.PURCHASED.ordinal
    @Suppress("DEPRECATION")
    constants["productResultCancelled"] = PLYProductViewResult.CANCELLED.ordinal
    @Suppress("DEPRECATION")
    constants["productResultRestored"] = PLYProductViewResult.RESTORED.ordinal
    constants["firebaseAppInstanceId"] = Attribute.FIREBASE_APP_INSTANCE_ID.ordinal
    constants["airshipChannelId"] = Attribute.AIRSHIP_CHANNEL_ID.ordinal
    constants["airshipUserId"] = Attribute.AIRSHIP_USER_ID.ordinal
    constants["batchInstallationId"] = Attribute.BATCH_INSTALLATION_ID.ordinal
    constants["adjustId"] = Attribute.ADJUST_ID.ordinal
    constants["appsflyerId"] = Attribute.APPSFLYER_ID.ordinal
    constants["mixpanelDistinctId"] = Attribute.MIXPANEL_DISTINCT_ID.ordinal
    constants["clevertapId"] = Attribute.CLEVER_TAP_ID.ordinal
    constants["sendinblueUserEmail"] = Attribute.SENDINBLUE_USER_EMAIL.ordinal
    constants["iterableUserId"] = Attribute.ITERABLE_USER_ID.ordinal
    constants["iterableUserEmail"] = Attribute.ITERABLE_USER_EMAIL.ordinal
    constants["atInternetIdClient"] = Attribute.AT_INTERNET_ID_CLIENT.ordinal
    constants["amplitudeUserId"] = Attribute.AMPLITUDE_USER_ID.ordinal
    constants["amplitudeDeviceId"] = Attribute.AMPLITUDE_DEVICE_ID.ordinal
    constants["mparticleUserId"] = Attribute.MPARTICLE_USER_ID.ordinal
    constants["customerIoUserId"] = Attribute.CUSTOMERIO_USER_ID.ordinal
    constants["customerIoUserEmail"] = Attribute.CUSTOMERIO_USER_EMAIL.ordinal
    constants["branchUserDeveloperIdentity"] = Attribute.BRANCH_USER_DEVELOPER_IDENTITY.ordinal
    constants["moEngageUniqueId"] = Attribute.MOENGAGE_UNIQUE_ID.ordinal
    constants["batchCustomUserId"] = Attribute.BATCH_CUSTOM_USER_ID.ordinal
    constants["sourceAppStore"] = StoreType.APPLE_APP_STORE.ordinal
    constants["sourcePlayStore"] = StoreType.GOOGLE_PLAY_STORE.ordinal
    constants["sourceHuaweiAppGallery"] = StoreType.HUAWEI_APP_GALLERY.ordinal
    constants["sourceAmazonAppstore"] = StoreType.AMAZON_APP_STORE.ordinal
    constants["sourceNone"] = StoreType.NONE.ordinal
    constants["consumable"] = DistributionType.CONSUMABLE.ordinal
    constants["nonConsumable"] = DistributionType.NON_CONSUMABLE.ordinal
    constants["autoRenewingSubscription"] = DistributionType.RENEWING_SUBSCRIPTION.ordinal
    constants["nonRenewingSubscription"] = DistributionType.NON_RENEWING_SUBSCRIPTION.ordinal
    constants["unknown"] = DistributionType.UNKNOWN.ordinal
    constants["runningModeTransactionOnly"] = runningModeTransactionOnly
    constants["runningModeObserver"] = runningModeObserver
    constants["runningModePaywallObserver"] = runningModePaywallObserver
    constants["runningModeFull"] = runningModeFull
    constants["presentationTypeNormal"] = PLYPresentationType.NORMAL.ordinal
    constants["presentationTypeFallback"] = PLYPresentationType.FALLBACK.ordinal
    constants["presentationTypeDeactivated"] = PLYPresentationType.DEACTIVATED.ordinal
    constants["presentationTypeClient"] = PLYPresentationType.CLIENT.ordinal
    constants["themeLight"] = PLYThemeMode.LIGHT.ordinal
    constants["themeDark"] = PLYThemeMode.DARK.ordinal
    constants["themeSystem"] = PLYThemeMode.SYSTEM.ordinal
    constants["userAttributeSourcePurchasely"] = PLYUserAttributeSource.PURCHASELY.ordinal
    constants["userAttributeSourceClient"] = PLYUserAttributeSource.CLIENT.ordinal
    constants["userAttributeString"] = PLYUserAttributeType.STRING.ordinal
    constants["userAttributeBoolean"] = PLYUserAttributeType.BOOLEAN.ordinal
    constants["userAttributeInt"] = PLYUserAttributeType.INT.ordinal
    constants["userAttributeFloat"] = PLYUserAttributeType.FLOAT.ordinal
    constants["userAttributeDate"] = PLYUserAttributeType.DATE.ordinal
    constants["userAttributeStringArray"] = PLYUserAttributeType.STRING_ARRAY.ordinal
    constants["userAttributeIntArray"] = PLYUserAttributeType.INT_ARRAY.ordinal
    constants["userAttributeFloatArray"] = PLYUserAttributeType.FLOAT_ARRAY.ordinal
    constants["userAttributeBooleanArray"] = PLYUserAttributeType.BOOLEAN_ARRAY.ordinal
    return constants
  }

  private fun getStoresInstances(stores: List<Any>): List<Store> {
    val result = ArrayList<Store>()
    if (stores.contains("Google")
      && Package.getPackage("io.purchasely.google") != null) {
      try {
        result.add(Class.forName("io.purchasely.google.GoogleStore").newInstance() as Store)
      } catch (e: Exception) {
        Log.e("Purchasely", "Google Store not found :" + e.message, e)
      }
    }
    if (stores.contains("Huawei")
      && Package.getPackage("io.purchasely.huawei") != null) {
      try {
        result.add(Class.forName("io.purchasely.huawei.HuaweiStore").newInstance() as Store)
      } catch (e: Exception) {
        Log.e("Purchasely", e.message, e)
      }
    }
    if (stores.contains("Amazon")
      && Package.getPackage("io.purchasely.amazon") != null) {
      try {
        result.add(Class.forName("io.purchasely.amazon.AmazonStore").newInstance() as Store)
      } catch (e: Exception) {
        Log.e("Purchasely", e.message, e)
      }
    }
    return result.toList()
  }

  @ReactMethod
  fun start(apiKey: String,
            stores: ReadableArray,
            storeKit1: Boolean,
            userId: String?,
            logLevel: Int,
            runningMode: Int,
            bridgeVersion: String,
            promise: Promise) {
    Purchasely.Builder(reactApplicationContext.applicationContext)
      .apiKey(apiKey)
      .stores(getStoresInstances(stores.toArrayList().filterNotNull()))
      .userId(userId)
      .logLevel(LogLevel.values()[logLevel])
      .runningMode(when(runningMode) {
        runningModeTransactionOnly -> PLYRunningMode.Full
        runningModeObserver -> PLYRunningMode.PaywallObserver
        runningModePaywallObserver -> PLYRunningMode.PaywallObserver
        else -> PLYRunningMode.Full
      })
      .build()

    Purchasely.eventListener = eventListener

    Purchasely.sdkBridgeVersion = bridgeVersion

    Purchasely.appTechnology = PLYAppTechnology.REACT_NATIVE

    Purchasely.start { isConfigured, error ->
      if(isConfigured) promise.resolve(true)
      else promise.reject(error ?: IllegalStateException("Purchasely start failed"))
    }

    Purchasely.purchaseListener = purchaseListener

    Purchasely.userAttributeListener = userAttributeListener
  }

  @ReactMethod
  fun close() {
    Purchasely.close()
  }

  @ReactMethod
  fun signPromotionalOffer(storeProductId: String, storeOfferId: String, promise: Promise) {
    promise.reject("Not supported on Android")
  }

  @ReactMethod
  fun getAnonymousUserId(promise: Promise) {
    promise.resolve(Purchasely.anonymousUserId)
  }

  @ReactMethod
  fun userLogin(userId: String, promise: Promise) {
    Purchasely.userLogin(userId) { refresh ->
        promise.resolve(refresh)
    }
  }

  @ReactMethod
  fun userLogout() {
    Purchasely.userLogout()
  }

  @ReactMethod
  fun setLogLevel(logLevel: Int) {
    Purchasely.logLevel = LogLevel.values()[logLevel]
  }

  @ReactMethod
  fun setLanguage(language: String) {
    Purchasely.language = try {
      Locale(language)
    } catch (e: Exception) {
      Locale.getDefault()
    }
  }

  @ReactMethod
  fun readyToOpenDeeplink(ready: Boolean) {
    Purchasely.readyToOpenDeeplink = ready
  }

  @ReactMethod
  fun setAttribute(attribute: Int, value: String?) {
    if(value == null) return
    Purchasely.setAttribute(Attribute.values()[attribute], value)
  }

  @ReactMethod
  fun setThemeMode(themeMode: Int) {
    Purchasely.setThemeMode(PLYThemeMode.values()[themeMode])
  }

  @ReactMethod
  fun setDefaultPresentationResultHandler(promise: Promise) {
    defaultPurchasePromise = promise
    Purchasely.setDefaultPresentationResultHandler { outcome ->
      sendPurchaseResultV6(outcome)
    }
  }

  @ReactMethod
  fun synchronize() {
    Purchasely.synchronize()
  }

  @ReactMethod
  fun productWithIdentifier(vendorId: String, promise: Promise) {
    GlobalScope.launch {
      try {
        val product = Purchasely.product(vendorId)
        promise.resolve(Arguments.makeNativeMap(product?.toMap() ?: emptyMap()))
      } catch (e: Exception) {
        promise.reject(e)
      }
    }
  }

  @ReactMethod
  fun planWithIdentifier(vendorId: String, promise: Promise) {
    GlobalScope.launch {
      try {
        val plan = Purchasely.plan(vendorId)
        promise.resolve(Arguments.makeNativeMap(transformPlanToMap(plan)))
      } catch (e: Exception) {
        promise.reject(e)
      }
    }
  }

  @ReactMethod
  fun allProducts(promise: Promise) {
    GlobalScope.launch {
      try {
        val products = Purchasely.allProducts()
        val result = ArrayList<ReadableMap?>()
        for (product in products) {
          result.add(Arguments.makeNativeMap(product.toMap()))
        }
        promise.resolve(Arguments.makeNativeArray(result))
      } catch (e: Exception) {
        promise.reject(e)
      }
    }
  }

  @ReactMethod
  fun purchaseWithPlanVendorId(planVendorId: String, offerId: String?, contentId: String?, promise: Promise) {
    GlobalScope.launch {
      try {
        val plan = Purchasely.plan(planVendorId)
        val offer = plan?.promoOffers?.firstOrNull { it.vendorId == offerId }
        if(plan != null) {
          Purchasely.purchase(
            activity = reactApplicationContext.currentActivity!!,
            plan = plan,
            offer = offer,
            contentId = contentId,
            onSuccess = {
              promise.resolve(Arguments.makeNativeMap(transformPlanToMap(it)))
            },
            onError = {
              promise.reject(it ?: IllegalStateException("Purchase failed"))
            }
          )
        } else {
          promise.reject(IllegalStateException("plan $planVendorId not found"))
        }
      } catch (e: Exception) {
        promise.reject(e)
      }
    }
  }

  @ReactMethod
  fun restoreAllProducts(promise: Promise) {
    Purchasely.restoreAllProducts(
      onSuccess = {
        promise.resolve(true)
      },
      onError = {
        promise.reject(it ?: IllegalStateException("Restore failed"))
      }
    )
  }

  @ReactMethod
  fun silentRestoreAllProducts(promise: Promise) {
    Purchasely.silentRestoreAllProducts(
      onSuccess = {
        promise.resolve(true)
      },
      onError = {
        promise.reject(it ?: IllegalStateException("Silent Restore failed"))
      }
    )
  }

  @ReactMethod
  fun displaySubscriptionCancellationInstruction() {
    Purchasely.displaySubscriptionCancellationInstruction(reactApplicationContext.currentActivity as FragmentActivity, 0)
  }

  private fun legalBasisFromString(basis: String?): PLYDataProcessingLegalBasis {
  return when (basis?.uppercase(Locale.ROOT)) {
    "ESSENTIAL" -> PLYDataProcessingLegalBasis.ESSENTIAL
    else -> PLYDataProcessingLegalBasis.OPTIONAL
  }
}

@ReactMethod
fun setUserAttributeWithString(key: String, value: String, legalBasis: String?) {
  Purchasely.setUserAttribute(key, value, legalBasisFromString(legalBasis))
}

@ReactMethod
fun setUserAttributeWithNumber(key: String, value: Double, legalBasis: String?) {
  val lb = legalBasisFromString(legalBasis)
  if (value.compareTo(value.toInt()) == 0) {
    Purchasely.setUserAttribute(key, value.toInt(), lb)
  } else {
    Purchasely.setUserAttribute(key, value.toFloat(), lb)
  }
}

@ReactMethod
fun setUserAttributeWithBoolean(key: String, value: Boolean, legalBasis: String?) {
  Purchasely.setUserAttribute(key, value, legalBasisFromString(legalBasis))
}

@ReactMethod
fun setUserAttributeWithDate(key: String, value: String, legalBasis: String?) {
  val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSX", Locale.getDefault())
  } else {
    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault())
  }
  format.timeZone = TimeZone.getTimeZone("GMT")
  val calendar = Calendar.getInstance()
  try {
    format.parse(value)?.let { calendar.time = it }
    Purchasely.setUserAttribute(key, calendar.time, legalBasisFromString(legalBasis))
  } catch (e: Exception) {
    Log.e("Purchasely", "Cannot save date attribute $key", e)
  }
}

@ReactMethod
fun setUserAttributeWithStringArray(key: String, value: ReadableArray, legalBasis: String?) {
  val array = value.toArrayList().mapNotNull { it?.toString() }.toTypedArray()
  Purchasely.setUserAttribute(key, array, legalBasisFromString(legalBasis))
}

@ReactMethod
fun setUserAttributeWithNumberArray(key: String, value: ReadableArray, legalBasis: String?) {
  val array = value.toArrayList()
    .mapNotNull { it?.toString()?.toFloatOrNull() }
    .toTypedArray()
  Purchasely.setUserAttribute(key, array, legalBasisFromString(legalBasis))
}

@ReactMethod
fun setUserAttributeWithBooleanArray(key: String, value: ReadableArray, legalBasis: String?) {
  val array = value.toArrayList()
    .mapNotNull {
      when (it) {
        is Boolean -> it
        is String -> it.equals("true", ignoreCase = true) || it == "1"
        is Number -> it.toInt() != 0
        else -> null
      }
    }
    .toTypedArray()
  Purchasely.setUserAttribute(key, array, legalBasisFromString(legalBasis))
}

@ReactMethod
fun incrementUserAttribute(key: String, value: Double, legalBasis: String?) {
  Purchasely.incrementUserAttribute(key, value.toInt(), legalBasisFromString(legalBasis))
}

@ReactMethod
fun decrementUserAttribute(key: String, value: Double, legalBasis: String?) {
  Purchasely.decrementUserAttribute(key, value.toInt(), legalBasisFromString(legalBasis))
}

  @ReactMethod
  fun userAttribute(key: String, promise: Promise) {
    val result = getUserAttributeValueForRN(Purchasely.userAttribute(key))
    promise.resolve(result)
  }

  @ReactMethod
  fun userAttributes(promise: Promise) {
    val map = Purchasely.userAttributes()
    promise.resolve(Arguments.makeNativeMap(
      map.mapValues {
        getUserAttributeValueForRN(it.value)
      }
    ))
  }

  private fun getUserAttributeValueForRN(value: Any?): Any? {
    return when (value) {
      is Date -> {
        val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
          SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSX", Locale.getDefault())
        } else {
          SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault())
        }
        format.timeZone = TimeZone.getTimeZone("GMT")
        try {
          format.format(value)
        } catch (e: Exception) {
          ""
        }
      }
      is Int -> value.toDouble()
      //awful but to keep same precision so 1.2f = 1.2 double and not 1.20000056
      is Float -> value.toString().toDouble()
      else -> value
    }
  }

  @ReactMethod
  fun clearUserAttribute(key: String) {
    Purchasely.clearUserAttribute(key)
  }

  @ReactMethod
  fun clearUserAttributes() {
    Purchasely.clearUserAttributes()
  }

  @ReactMethod
  fun clientPresentationDisplayed(presentationMap: ReadableMap?) {
      if(presentationMap == null) {
        PLYLogger.e("presentation cannot be null")
        return
      }

    val presentation = presentationsLoaded.firstOrNull { it.id ==  presentationMap.getString("id")}

    if(presentation != null) {
      Purchasely.clientPresentationDisplayed(presentation)
    }
  }

  @ReactMethod
  fun clientPresentationClosed(presentationMap: ReadableMap?) {
    if(presentationMap == null) {
      PLYLogger.e("presentation cannot be null")
      return
    }

    val presentation = presentationsLoaded.firstOrNull { it.id ==  presentationMap.getString("id")}

    if(presentation != null) {
      Purchasely.clientPresentationClosed(presentation)
    }

  }

  @ReactMethod
  fun userSubscriptions(invalidate: Boolean = false, promise: Promise) {
    GlobalScope.launch {
      try {
        val subscriptions = Purchasely.userSubscriptions(invalidate)
        val result = ArrayList<ReadableMap?>()
        for (data in subscriptions) {
          val map = data.data.toMap().toMutableMap().apply {
            this["subscriptionSource"] = when(data.data.storeType) {
              StoreType.GOOGLE_PLAY_STORE -> StoreType.GOOGLE_PLAY_STORE.ordinal
              StoreType.HUAWEI_APP_GALLERY -> StoreType.HUAWEI_APP_GALLERY.ordinal
              StoreType.AMAZON_APP_STORE -> StoreType.AMAZON_APP_STORE.ordinal
              StoreType.APPLE_APP_STORE -> StoreType.APPLE_APP_STORE.ordinal
              else -> null
            }
            if(data.data.plan == null) {
              this["plan"] = transformPlanToMap(data.plan)
            }
            this["product"] = data.product.toMap()
            remove("subscription_status") //Add in a next version
          }
          result.add(Arguments.makeNativeMap(map))
        }
        promise.resolve(Arguments.makeNativeArray(result))
      } catch (e: Exception) {
        promise.reject(e)
      }
    }
  }

  @ReactMethod
  fun userSubscriptionsHistory(promise: Promise) {
    GlobalScope.launch {
      try {
        val subscriptions = Purchasely.userSubscriptionsHistory()
        val result = ArrayList<ReadableMap?>()
        for (data in subscriptions) {
          val map = data.data.toMap().toMutableMap().apply {
            this["subscriptionSource"] = when(data.data.storeType) {
              StoreType.GOOGLE_PLAY_STORE -> StoreType.GOOGLE_PLAY_STORE.ordinal
              StoreType.HUAWEI_APP_GALLERY -> StoreType.HUAWEI_APP_GALLERY.ordinal
              StoreType.AMAZON_APP_STORE -> StoreType.AMAZON_APP_STORE.ordinal
              StoreType.APPLE_APP_STORE -> StoreType.APPLE_APP_STORE.ordinal
              else -> null
            }
            if(data.data.plan == null) {
              this["plan"] = transformPlanToMap(data.plan)
            }
            this["product"] = data.product.toMap()
            remove("subscription_status") //Add in a next version
          }
          result.add(Arguments.makeNativeMap(map))
        }
        promise.resolve(Arguments.makeNativeArray(result))
      } catch (e: Exception) {
        promise.reject(e)
      }
    }
  }

  @ReactMethod
  fun presentSubscriptions() {
    val intent = Intent(reactApplicationContext.applicationContext, PLYSubscriptionsActivity::class.java)
    reactApplicationContext.currentActivity?.startActivity(intent)
  }

  @ReactMethod
  fun isDeeplinkHandled(deeplink: String?, promise: Promise) {
    if (deeplink == null) {
      promise.reject(IllegalStateException("Deeplink must not be null"))
      return
    }
    val uri = Uri.parse(deeplink)
    promise.resolve(Purchasely.isDeeplinkHandled(uri))
  }

  @ReactMethod
  fun isEligibleForIntroOffer(planVendorId: String, promise: Promise) {
    GlobalScope.launch {
      try {
        val plan = Purchasely.plan(planVendorId)
        if(plan != null) {
          promise.resolve(plan.isEligibleToOffer())
        } else {
          promise.reject(IllegalStateException("plan $planVendorId not found"))
        }
      } catch (e: Exception) {
        promise.reject(e)
      }
    }
  }

  @ReactMethod
  fun isAnonymous(promise: Promise) {
    promise.resolve(Purchasely.isAnonymous())
  }

  @ReactMethod
  fun userDidConsumeSubscriptionContent() {
    Purchasely.userDidConsumeSubscriptionContent()
  }

  private fun sendEvent(reactContext: ReactContext,
                        eventName: String,
                        params: WritableMap?) {
    reactContext
      .getJSModule(RCTDeviceEventEmitter::class.java)
      .emit(eventName, params)
  }

  @ReactMethod
  fun clearBuiltInAttributes() {
    Purchasely.clearBuiltInAttributes()
  }

  @ReactMethod
  fun setDynamicOffering(reference: String, planVendorId: String, offerId: String?, promise: Promise) {
     Purchasely.setDynamicOffering(reference, planVendorId, offerId) {
       promise.resolve(it)
     }
  }

  @ReactMethod
  fun getDynamicOfferings(promise: Promise) {
    Purchasely.getDynamicOfferings { offerings ->
      val result = ArrayList<ReadableMap?>()
      for (offering in offerings) {
        val map = mutableMapOf<String, String>()
        map["reference"] = offering.reference
        map["planVendorId"] = offering.planId
        if (offering.offerId != null) map["offerVendorId"] = offering.offerId!!
        result.add(Arguments.makeNativeMap(map.toMap()))
      }
      promise.resolve(Arguments.makeNativeArray(result))
    }
  }

  @ReactMethod
  fun removeDynamicOffering(reference: String) {
    Purchasely.removeDynamicOffering(reference)
  }

  @ReactMethod
  fun clearDynamicOfferings() {
    Purchasely.clearDynamicOfferings()
  }

  @ReactMethod
  fun revokeDataProcessingConsent(purposes: ReadableArray) {
    val mapped = mapPurposesFromReadableArray(purposes)

    if (mapped.isEmpty()) {
      Log.w("Purchasely", "revokeDataProcessingConsent called with no valid purposes: $purposes")
      return
    }

    // SDK call — adjust if your signature differs
    Purchasely.revokeDataProcessingConsent(mapped)
  }

  @ReactMethod
  fun setDebugMode(enabled: Boolean) {
    Purchasely.debugMode = enabled
  }

  // region v6 — cross-platform bridge methods
  // See: reports/v6-presentation-comparison-v3-claude/BRIDGE-CONTRACT.md
  //
  // The v6 bridge logic lives directly in this single native module. Lifecycle
  // events are emitted over the existing RCTDeviceEventEmitter using the
  // PURCHASELY_V6_* event names. State + constants are in the companion object.

  /** v6 preload entry point. JS calls this with a requestId + builder payload. */
  @ReactMethod
  fun v6Preload(requestId: String, payload: ReadableMap?, promise: Promise) {
    try {
      val prepared = buildV6Prepared(payload)
      activeV6Requests[requestId] = prepared
      wireV6Callbacks(requestId, prepared)

      prepared.preload { loaded, error ->
        val map = Arguments.createMap()
        map.putString("requestId", requestId)
        loaded?.let { map.putMap("presentation", it.toV6Map()) }
        error?.let { map.putMap("error", it.toV6Map()) }
        sendEvent(reactApplicationContext, EVENT_V6_LOADED, map)
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
  @ReactMethod
  fun v6Display(
    requestId: String,
    payload: ReadableMap?,
    transition: ReadableMap?,
    promise: Promise
  ) {
    try {
      val activity: Activity = reactApplicationContext.currentActivity
        ?: throw IllegalStateException("No current activity to host the presentation")

      val prepared = activeV6Requests[requestId] ?: buildV6Prepared(payload).also {
        activeV6Requests[requestId] = it
        wireV6Callbacks(requestId, it)
      }

      val plyTransition: PLYTransition? = transition?.let { tm ->
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

      // The outcome is emitted to JS through `onDismissed` (wired in
      // `wireV6Callbacks`), so the local `callback` is a noop. We still pass an
      // outcome handler so the SDK does not log a missing-callback warning.
      prepared.display(
        context = activity,
        transition = plyTransition,
        presentation = null,
        callback = { /* dismissed event is sent via onDismissed */ }
      )

      promise.resolve(true)
    } catch (e: Throwable) {
      // Reject only — the JS `.catch` on v6Display synthesizes the dismissed
      // outcome (onPresented(null, error) + onDismissed), mirroring the iOS
      // error path. Emitting a DISMISSED event here too would invoke the
      // user-supplied onDismissed callback twice.
      activeV6Requests.remove(requestId)
      promise.reject("v6_display_failure", e.message, e)
    }
  }

  @ReactMethod
  fun v6Close(requestId: String) {
    activeV6Requests.remove(requestId)
    // The SDK v6 does not yet expose a per-request close, so this dismisses
    // *every* displayed presentation, not just `requestId`. Warn the host when
    // other requests are still active so tearing down a stacked presentation is
    // not a silent surprise.
    if (activeV6Requests.isNotEmpty()) {
      PLYLogger.w(
        "[v6] close($requestId) dismisses ALL displayed presentations " +
          "(per-request close is not yet supported by the native SDK); " +
          "${activeV6Requests.size} other active request(s) will also be closed."
      )
    }
    Purchasely.closeAllScreens()
  }

  @ReactMethod
  fun v6Back(requestId: String) {
    // No public `back()` on the Java façade — surface as a noop log.
    PLYLogger.w("[v6] back($requestId) is not yet bridged on Android")
  }

  /** Register an interceptor for a given action kind. */
  @ReactMethod
  fun v6RegisterInterceptor(kind: String) {
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
      pendingV6Interceptors[callbackId] = deferred

      val payload = Arguments.createMap()
      payload.putString("requestId", "")
      payload.putString("callbackId", callbackId)
      payload.putString("kind", kind)
      payload.putMap("info", info.toV6Map())
      payload.putMap("payload", action.toV6Payload())
      sendEvent(reactApplicationContext, EVENT_V6_ACTION_INTERCEPTED, payload)

      CoroutineScope(Dispatchers.Main).launch {
        // Bound the suspension: `withTimeoutOrNull` returns null if JS never
        // calls back within INTERCEPTOR_TIMEOUT_MS, and `runCatching` guards
        // against the deferred being cancelled. In every case we default to
        // NOT_HANDLED and drop the pending entry so neither the SDK action nor
        // the `complete` lambda is held alive forever.
        val result = runCatching {
          withTimeoutOrNull(INTERCEPTOR_TIMEOUT_MS) { deferred.await() }
        }.getOrNull() ?: PLYInterceptResult.NOT_HANDLED
        pendingV6Interceptors.remove(callbackId)
        complete(result)
      }
    }
  }

  @ReactMethod
  fun v6UnregisterInterceptor(kind: String) {
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

  @ReactMethod
  fun v6CompleteInterceptor(callbackId: String, result: String) {
    val deferred = pendingV6Interceptors.remove(callbackId) ?: return
    deferred.complete(
      when (result) {
        "success" -> PLYInterceptResult.SUCCESS
        "failed" -> PLYInterceptResult.FAILED
        else -> PLYInterceptResult.NOT_HANDLED
      }
    )
  }

  @ReactMethod
  fun v6ApplyStartOptions(options: ReadableMap) {
    if (options.hasKey("allowDeeplink") && !options.isNull("allowDeeplink")) {
      Purchasely.readyToOpenDeeplink = options.getBoolean("allowDeeplink")
    }
    if (options.hasKey("allowCampaigns") && !options.isNull("allowCampaigns")) {
      // No direct setter for "disallowCampaigns" — leverage the privacy API.
      // If the host opts out, we record it through the consent manager.
      if (!options.getBoolean("allowCampaigns")) {
        runCatching {
          Purchasely.revokeDataProcessingConsent(
            setOf(PLYDataProcessingPurpose.Campaigns)
          )
        }.onFailure {
          PLYLogger.w("[v6] allowCampaigns(false) could not be honored: ${it.message}")
        }
      }
    }
  }

  // --- v6 private helpers ---

  /**
   * Build a [PLYPresentationBase.Prepared] from the JS payload.
   *
   * The JS `isDefault` flag (set by `PresentationBuilder.default()`) is
   * intentionally **not** read here: a `default()` request carries no
   * `placementId` and no `presentationId`, and the native SDK resolves the
   * default presentation (`ply_default`) precisely from that absence —
   * `PLYPresentationManager.getPresentation` routes a request with both ids
   * null to `apiService.getPresentation(null)`, which substitutes
   * `"ply_default"`. An empty builder is therefore the Android equivalent of
   * iOS `fetchPresentationWith:nil`, so no `isDefault` branch is required.
   */
  private fun buildV6Prepared(payload: ReadableMap?): PLYPresentationBase.Prepared {
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

  private fun wireV6Callbacks(requestId: String, prepared: PLYPresentationBase.Prepared) {
    prepared.onPresented = { presentation, error ->
      val payload = Arguments.createMap()
      payload.putString("requestId", requestId)
      presentation?.let { payload.putMap("presentation", it.toV6Map()) }
      error?.let { payload.putMap("error", it.toV6Map()) }
      sendEvent(reactApplicationContext, EVENT_V6_PRESENTED, payload)
    }
    prepared.onCloseRequested = {
      val payload = Arguments.createMap()
      payload.putString("requestId", requestId)
      sendEvent(reactApplicationContext, EVENT_V6_CLOSE_REQUESTED, payload)
    }
    prepared.onDismissed = { outcome: PLYPresentationOutcome ->
      val payload = Arguments.createMap()
      payload.putString("requestId", requestId)
      outcome.presentation?.let { payload.putMap("presentation", it.toV6Map()) }
      outcome.purchaseResult?.let { payload.putInt("purchaseResult", it.toV6Ordinal()) }
      outcome.plan?.let {
        payload.putMap("plan", Arguments.makeNativeMap(
          transformPlanToMap(it).toMutableMap()
        ))
      }
      outcome.closeReason?.let { payload.putString("closeReason", it.toV6String()) }
      outcome.error?.let { payload.putMap("error", it.toV6Map()) }
      sendEvent(reactApplicationContext, EVENT_V6_DISMISSED, payload)
      activeV6Requests.remove(requestId)
    }
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

  private fun PLYPurchaseResult.toV6Ordinal(): Int = when (this) {
    PLYPurchaseResult.PURCHASED -> 0
    PLYPurchaseResult.CANCELLED -> 1
    PLYPurchaseResult.RESTORED -> 2
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
            transformPlanToMap(plan).toMutableMap()
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

  // endregion

  private fun mapPurposesFromReadableArray(purposes: ReadableArray): Set<PLYDataProcessingPurpose> {
    val result = mutableSetOf<PLYDataProcessingPurpose>()

    // Check if any element equals "all-non-essentials"
    for (i in 0 until purposes.size()) {
      if (purposes.getString(i) == "all-non-essentials") {
        result.add(PLYDataProcessingPurpose.AllNonEssentials)
        return result
      }
    }

    purposes.toArrayList().forEach { any ->
      val s = (any as? String)?.lowercase(Locale.ROOT) ?: return@forEach
      when (s) {
        "all-non-essentials" -> result.add(PLYDataProcessingPurpose.AllNonEssentials)
        "analytics" -> result.add(PLYDataProcessingPurpose.Analytics)
        "identified-analytics" -> result.add(PLYDataProcessingPurpose.IdentifiedAnalytics)
        "campaigns" -> result.add(PLYDataProcessingPurpose.Campaigns)
        "personalization" -> result.add(PLYDataProcessingPurpose.Personalization)
        "third-party-integration" -> result.add(PLYDataProcessingPurpose.ThirdPartyIntegrations)
        // silently ignore unknown strings
      }
    }
    return result
  }

  companion object {
    private const val runningModeTransactionOnly = 0
    private const val runningModeObserver = 1
    private const val runningModePaywallObserver = 3
    private const val runningModeFull = 4

    // v6 bridge — event names, interceptor timeout, and per-request state
    // (kept in the companion to preserve the process-global semantics the
    // former standalone PurchaselyV6Bridge object had).
    private const val EVENT_V6_LOADED = "PURCHASELY_V6_LOADED"
    private const val EVENT_V6_PRESENTED = "PURCHASELY_V6_PRESENTED"
    private const val EVENT_V6_CLOSE_REQUESTED = "PURCHASELY_V6_CLOSE_REQUESTED"
    private const val EVENT_V6_DISMISSED = "PURCHASELY_V6_DISMISSED"
    private const val EVENT_V6_ACTION_INTERCEPTED = "PURCHASELY_V6_ACTION_INTERCEPTED"

    /**
     * Upper bound on how long the bridge waits for JS to resolve an intercepted
     * action via [v6CompleteInterceptor]. If the JS handler never calls back
     * (e.g. the event listener was torn down by a bridge reload), we fall back to
     * [PLYInterceptResult.NOT_HANDLED] so the SDK is never blocked indefinitely.
     */
    private const val INTERCEPTOR_TIMEOUT_MS = 30_000L

    /** Active v6 presentation requests, keyed by the JS-supplied requestId. */
    private val activeV6Requests = ConcurrentHashMap<String, PLYPresentationBase.Prepared>()

    /** Pending v6 interceptor callbacks, resolved when JS calls v6CompleteInterceptor. */
    private val pendingV6Interceptors =
      ConcurrentHashMap<String, CompletableDeferred<PLYInterceptResult>>()

    val presentationsLoaded = mutableListOf<PLYPresentation>()

    var purchasePromise: Promise? = null
    var defaultPurchasePromise: Promise? = null

    /**
     * Backwards-compatible projection of a v6 `PLYPresentationOutcome` into the
     * legacy `{result, plan}` shape consumed by the v5 JS API. The new v6 façade
     * exposes the full outcome (with `closeReason` / `error`) via the dedicated
     * `PURCHASELY_V6_DISMISSED` event.
     */
    fun sendPurchaseResultV6(outcome: io.purchasely.ext.presentation.PLYPresentationOutcome) {
      val resultOrdinal = when (outcome.purchaseResult) {
        io.purchasely.ext.presentation.PLYPurchaseResult.PURCHASED -> 0
        io.purchasely.ext.presentation.PLYPurchaseResult.RESTORED -> 2
        io.purchasely.ext.presentation.PLYPurchaseResult.CANCELLED -> 1
        null -> 1
      }
      val map: MutableMap<String, Any?> = HashMap()
      map["result"] = resultOrdinal
      map["plan"] = transformPlanToMap(outcome.plan)
      purchasePromise?.resolve(Arguments.makeNativeMap(map))
        ?: defaultPurchasePromise?.resolve(Arguments.makeNativeMap(map))
    }

    fun transformPlanToMap(plan: PLYPlan?): Map<String, Any?> {
      if(plan == null) return emptyMap()

      return plan.toMap().toMutableMap().apply {
        this["type"] = when(plan.type) {
          DistributionType.RENEWING_SUBSCRIPTION -> DistributionType.RENEWING_SUBSCRIPTION.ordinal
          DistributionType.NON_RENEWING_SUBSCRIPTION -> DistributionType.NON_RENEWING_SUBSCRIPTION.ordinal
          DistributionType.CONSUMABLE -> DistributionType.CONSUMABLE.ordinal
          DistributionType.NON_CONSUMABLE -> DistributionType.NON_CONSUMABLE.ordinal
          DistributionType.UNKNOWN -> DistributionType.UNKNOWN.ordinal
          else -> null
        }
      }
    }
  }

  fun PLYPresentationPlan.toMap(): Map<String, String?> {
    return mapOf(
      Pair("planVendorId", planVendorId),
      Pair("storeProductId", storeProductId),
      Pair("basePlanId", basePlanId),
      Pair("storeOfferId", storeOfferId)
    )
  }

  suspend fun io.purchasely.ext.presentation.PLYPresentationMetadata.toMap(): Map<String, Any> {
    val metadata = mutableMapOf<String, Any>()
    this.keys()?.forEach { key ->
      val value = when (this.type(key)) {
        kotlin.String::class.java.simpleName -> this.getString(key)
        else -> this.get(key)
      }
      value?.let {
        metadata.put(key, it)
      }
    }

    return metadata
  }
}
