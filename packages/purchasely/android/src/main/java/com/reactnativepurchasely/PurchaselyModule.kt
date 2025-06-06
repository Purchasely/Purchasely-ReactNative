package com.reactnativepurchasely

import android.app.Activity
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
import io.purchasely.models.PLYError
import io.purchasely.models.PLYPlan
import io.purchasely.models.PLYPromoOffer
import io.purchasely.models.PLYPresentationPlan
import io.purchasely.storage.userData.PLYUserAttributeSource
import io.purchasely.storage.userData.PLYUserAttributeType
import io.purchasely.views.presentation.PLYThemeMode
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.lang.ref.WeakReference
import java.text.SimpleDateFormat
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap

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
        Pair("source", source.ordinal)
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
    constants["productResultPurchased"] = PLYProductViewResult.PURCHASED.ordinal
    constants["productResultCancelled"] = PLYProductViewResult.CANCELLED.ordinal
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

  @Deprecated("Should use start method", ReplaceWith("start"))
  @ReactMethod
  fun startWithAPIKey(apiKey: String,
                      stores: ReadableArray,
                      userId: String?,
                      logLevel: Int,
                      runningMode: Int,
                      bridgeVersion: String,
                      promise: Promise) {

    start(apiKey, stores, false, userId, logLevel, runningMode, bridgeVersion, promise)
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
    productActivity = null
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
    Purchasely.setDefaultPresentationResultHandler { result, plan ->
      sendPurchaseResult(result, plan)
    }
  }

  @ReactMethod
  fun synchronize() {
    Purchasely.synchronize()
  }

  @ReactMethod
  fun fetchPresentation(placementId: String?,
                        presentationId: String?,
                        contentId: String?,
                        promise: Promise) {


    val properties = PLYPresentationProperties(
      placementId = placementId,
      presentationId = presentationId,
      contentId = contentId)


    Purchasely.fetchPresentation(properties = properties) { presentation: PLYPresentation?, error: PLYError? ->
      GlobalScope.launch {
        if(presentation != null) {
          mutex.withLock {
            presentationsLoaded.removeAll { it.id == presentation.id && it.placementId == presentation.placementId }
            presentationsLoaded.add(presentation)
            val map = presentation.toMap().mapValues {
              val value = it.value
              if(value is PLYPresentationType) value.ordinal
              else value
            }

            val mutableMap = map.toMutableMap().apply {
              this["metadata"] = presentation.metadata?.toMap()
              this["plans"] = (this["plans"] as List<PLYPresentationPlan>).map { it.toMap() }
              this["height"] = presentation.height ?: 0
            }
            promise.resolve(Arguments.makeNativeMap(mutableMap))
          }
        }
        if(error != null) promise.reject(IllegalStateException(error.message ?: "Unable to fetch presentation"))
      }
    }
  }

  @ReactMethod
  fun presentPresentation(presentationMap: ReadableMap?,
                          isFullScreen: Boolean,
                          loadingBackgroundColor: String?,
                          promise: Promise) {
    if (presentationMap == null) {
      promise.reject(NullPointerException("presentation cannot be null"))
      return
    }

    val presentation = presentationsLoaded.lastOrNull {
      it.id == presentationMap.getString("id")
      && it.placementId == presentationMap.getString("placementId")
    }
    if(presentation == null) {
      promise.reject(NullPointerException("presentation not fond"))
      return
    }

    purchasePromise = promise

    reactApplicationContext.currentActivity?.let { activity ->
      val intent = PLYProductActivity.newIntent(activity, PLYPresentationProperties(), isFullScreen, loadingBackgroundColor).apply {
        putExtra("presentation", presentation)
      }
      activity.startActivity(intent)
    }

  }

  @ReactMethod
  fun presentPresentationWithIdentifier(presentationVendorId: String?,
                                        contentId: String?,
                                        isFullScreen: Boolean,
                                        loadingBackgroundColor: String?,
                                        promise: Promise) {
    purchasePromise = promise
    reactApplicationContext.currentActivity?.let {
      val properties = PLYPresentationProperties(
        presentationId = presentationVendorId,
        contentId = contentId
      )
      val intent = PLYProductActivity.newIntent(it, properties, isFullScreen, loadingBackgroundColor)
      it.startActivity(intent)
    }
  }

  @ReactMethod
  fun presentPresentationForPlacement(placementVendorId: String?,
                                      contentId: String?,
                                      isFullScreen: Boolean,
                                      loadingBackgroundColor: String?,
                                      promise: Promise) {
    purchasePromise = promise
    reactApplicationContext.currentActivity?.let {
      val properties = PLYPresentationProperties(
        placementId = placementVendorId,
        contentId = contentId
      )
      val intent = PLYProductActivity.newIntent(it, properties, isFullScreen, loadingBackgroundColor)
      it.startActivity(intent)
    }
  }

  @ReactMethod
  fun presentProductWithIdentifier(productVendorId: String,
                                   presentationVendorId: String?,
                                   contentId: String?,
                                   isFullScreen: Boolean,
                                   loadingBackgroundColor: String?,
                                   promise: Promise) {
    purchasePromise = promise
    reactApplicationContext.currentActivity?.let {
      val properties = PLYPresentationProperties(
        presentationId = presentationVendorId,
        productId = productVendorId,
        contentId = contentId
      )
      val intent = PLYProductActivity.newIntent(it, properties, isFullScreen, loadingBackgroundColor)
      it.startActivity(intent)
    }
  }

  @ReactMethod
  fun presentPlanWithIdentifier(planVendorId: String,
                                presentationVendorId: String?,
                                contentId: String?,
                                isFullScreen: Boolean,
                                loadingBackgroundColor: String?,
                                promise: Promise) {
    purchasePromise = promise
    reactApplicationContext.currentActivity?.let {
      val properties = PLYPresentationProperties(
        presentationId = presentationVendorId,
        planId = planVendorId,
        contentId = contentId
      )
      val intent = PLYProductActivity.newIntent(it, properties, isFullScreen, loadingBackgroundColor)
      it.startActivity(intent)
    }
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

  @ReactMethod
  fun setUserAttributeWithString(key: String, value: String) {
    Purchasely.setUserAttribute(key, value)
  }

  @ReactMethod
  fun setUserAttributeWithNumber(key: String, value: Double) {
   if(value.compareTo(value.toInt()) == 0) {
     Purchasely.setUserAttribute(key, value.toInt())
   } else {
     Purchasely.setUserAttribute(key, value.toFloat())
   }
  }

  @ReactMethod
  fun setUserAttributeWithBoolean(key: String, value: Boolean) {
    Purchasely.setUserAttribute(key, value)
  }

  @ReactMethod
  fun setUserAttributeWithStringArray(key: String, value: ReadableArray) {
    val array = value.toArrayList().mapNotNull { it.toString() }.toTypedArray()
    Purchasely.setUserAttribute(key, array)
  }

@ReactMethod
fun setUserAttributeWithNumberArray(key: String, value: ReadableArray) {
    val array = value.toArrayList().mapNotNull { it.toString().toFloat() }.toTypedArray()
    Purchasely.setUserAttribute(key, array)
}

  @ReactMethod
  fun setUserAttributeWithBooleanArray(key: String, value: ReadableArray) {
    val array = value.toArrayList().mapNotNull { it.toString().toBoolean() }.toTypedArray()
    Purchasely.setUserAttribute(key, array)
  }

  @ReactMethod
  fun setUserAttributeWithDate(key: String, value: String) {
    val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSX", Locale.getDefault())
    } else {
      SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault())
    }
    format.timeZone = TimeZone.getTimeZone("GMT")
    val calendar = Calendar.getInstance()
    try {
      format.parse(value)?.let {
        calendar.time = it
      }
      Purchasely.setUserAttribute(key, calendar.time)
    } catch (e: Exception) {
      Log.e("Purchasely", "Cannot save date attribute $key", e)
    }
  }

  @ReactMethod
  fun incrementUserAttribute(key: String, value: Double) {
    Purchasely.incrementUserAttribute(key, value.toInt())
  }

  @ReactMethod
  fun decrementUserAttribute(key: String, value: Double) {
    Purchasely.decrementUserAttribute(key, value.toInt())
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
  fun setPaywallActionInterceptor(promise: Promise) {
    Purchasely.setPaywallActionsInterceptor { info, action, parameters, processAction ->
      paywallActionHandler = processAction
      paywallAction = action

      val parametersForReact = hashMapOf<String, Any?>();
      parametersForReact["title"] = parameters.title
      parametersForReact["url"] = parameters.url?.toString()
      parametersForReact["plan"] = transformPlanToMap(parameters.plan)
      parametersForReact["offer"] = mapOf(
        "vendorId" to parameters.offer?.vendorId,
        "storeOfferId" to parameters.offer?.storeOfferId
      )
      parametersForReact["subscriptionOffer"] = parameters.subscriptionOffer?.toMap()
      parametersForReact["presentation"] = parameters.presentation
      parametersForReact["placement"] = parameters.placement

      promise.resolve(Arguments.makeNativeMap(
        mapOf(
          Pair("info", mapOf(
            Pair("contentId", info?.contentId),
            Pair("presentationId", info?.presentationId),
            Pair("placementId", info?.placementId),
            Pair("abTestId", info?.abTestId),
            Pair("abTestVariantId", info?.abTestVariantId)
          )),
          Pair("action", action.value),
          Pair("parameters", parametersForReact.filterNot { it.value == null })
        )
      ))
    }
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
  fun showPresentation() {
    CoroutineScope(Dispatchers.Main).launch {
      if (productActivity?.relaunch(reactApplicationContext) == false) {
        //wait for activity to relaunch
        withContext(Dispatchers.Default) { delay(500) }
      }
    }
  }

  @ReactMethod
  fun onProcessAction(processAction: Boolean) {
    CoroutineScope(Dispatchers.Default).launch {
      delay(500)
      val activityHandler = productActivity?.activity?.get() ?: reactApplicationContext.currentActivity
      withContext(Dispatchers.Main) {
        activityHandler?.runOnUiThread {
          paywallActionHandler?.invoke(processAction)
        }
      }
    }
  }

  @ReactMethod
  fun closePresentation() {
    Purchasely.closeAllScreens()
    productActivity = null
  }

  @ReactMethod
  fun hidePresentation() {
    val reactActivity = reactApplicationContext.currentActivity ?: return
    val activity = productActivity?.activity?.get() ?: reactActivity
    activity.startActivity(
      Intent(activity, reactActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
      }
    )
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

  companion object {
    private const val runningModeTransactionOnly = 0
    private const val runningModeObserver = 1
    private const val runningModePaywallObserver = 3
    private const val runningModeFull = 4

    val presentationsLoaded = mutableListOf<PLYPresentation>()

    var productActivity: ProductActivity? = null
    var purchasePromise: Promise? = null
    var defaultPurchasePromise: Promise? = null
    var paywallActionHandler: PLYCompletionHandler? = null
    var paywallAction: PLYPresentationAction? = null

    fun sendPurchaseResult(result: PLYProductViewResult, plan: PLYPlan?) {
      val productViewResult = when(result) {
        PLYProductViewResult.PURCHASED -> PLYProductViewResult.PURCHASED.ordinal
        PLYProductViewResult.CANCELLED -> PLYProductViewResult.CANCELLED.ordinal
        PLYProductViewResult.RESTORED -> PLYProductViewResult.RESTORED.ordinal
      }

      val map: MutableMap<String, Any?> = HashMap()
      map["result"] = productViewResult
      map["plan"] = transformPlanToMap(plan)
      purchasePromise?.resolve(Arguments.makeNativeMap(map)) ?: defaultPurchasePromise?.resolve(Arguments.makeNativeMap(map))
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

  class ProductActivity(
    val presentation: PLYPresentation? = null,
    val presentationId: String? = null,
    val placementId: String? = null,
    val productId: String? = null,
    val planId: String? = null,
    val contentId: String? = null,
    val isFullScreen: Boolean = false,
    val loadingBackgroundColor: String? = null) {

    var activity: WeakReference<Activity>? = null


    fun relaunch(reactApplicationContext: ReactApplicationContext) : Boolean {
      val backgroundActivity = activity?.get()
      return if(backgroundActivity != null
          && !backgroundActivity.isFinishing
          && !backgroundActivity.isDestroyed) {
        reactApplicationContext.currentActivity?.let {
          it.startActivity(
            Intent(it, backgroundActivity::class.java).apply {
              //flags = Intent.FLAG_ACTIVITY_NEW_TASK
              flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            }
          )
        }
        true
      } else {
        reactApplicationContext.currentActivity?.let {
          val properties = PLYPresentationProperties(
            presentationId = presentationId,
            placementId = placementId,
            productId = productId,
            planId = planId,
            contentId = contentId
          )
          val intent = PLYProductActivity.newIntent(it, properties, isFullScreen, loadingBackgroundColor).apply {
            putExtra("presentation", presentation)
          }
          it.startActivity(intent)
        }
        return false
      }
    }
  }

  fun PLYPresentationPlan.toMap() : Map<String, String?> {
    return mapOf(
      Pair("planVendorId", planVendorId),
      Pair("storeProductId", storeProductId),
      Pair("basePlanId", basePlanId),
      Pair("storeOfferId", storeOfferId)
    )
  }

  suspend fun PLYPresentationMetadata.toMap() : Map<String, Any> {
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
