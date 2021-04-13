package com.reactnativepurchasely

import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.fragment.app.FragmentActivity
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import io.purchasely.billing.Store
import io.purchasely.ext.*
import io.purchasely.models.PLYPlan
import io.purchasely.models.PLYProduct
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch

class PurchaselyModule internal constructor(context: ReactApplicationContext) : ReactContextBaseJavaModule(context) {

  private val eventListener: EventListener = object: EventListener {
    override fun onEvent(event: PLYEvent) {
      //Log.d("Purchasely", "Event from Module : ${event::class.java.simpleName}")
      //Log.d("Purchasely", "${event.name} : ${event.properties?.toMap()}")
      if (event.properties != null) {
        val map = mapOf(
          Pair("name", event.name),
          Pair("properties", event.properties!!.toMap())
        )
        sendEvent(reactApplicationContext, "PURCHASELY_EVENTS", Arguments.makeNativeMap(map))
      } else {
        val map = mapOf(Pair("name", event.name))
        sendEvent(reactApplicationContext, "PURCHASELY_EVENTS", Arguments.makeNativeMap(map))
      }
    }
  }

  private val purchaseListener: PurchaseListener = object: PurchaseListener {
    override fun onPurchaseStateChanged(state: State) {
      if(state is State.PurchaseComplete || state is State.RestorationComplete) {
        sendEvent(reactApplicationContext, "PURCHASE_LISTENER", null)
      }
    }
  }

  override fun getName(): String {
    return "Purchasely"
  }

  override fun getConstants(): Map<String, Any>? {
    val constants: MutableMap<String, Any> = HashMap()
    constants["logLevelDebug"] = LogLevel.DEBUG.ordinal
    constants["logLevelWarn"] = LogLevel.WARN.ordinal
    constants["logLevelInfo"] = LogLevel.INFO.ordinal
    constants["logLevelError"] = LogLevel.ERROR.ordinal
    constants["productResultPurchased"] = PLYProductViewResult.PURCHASED.ordinal
    constants["productResultCancelled"] = PLYProductViewResult.CANCELLED.ordinal
    constants["productResultRestored"] = PLYProductViewResult.RESTORED.ordinal
    constants["amplitudeSessionId"] = Attribute.AMPLITUDE_SESSION_ID.ordinal
    constants["firebaseAppInstanceId"] = Attribute.FIREBASE_APP_INSTANCE_ID.ordinal
    constants["airshipChannelId"] = Attribute.AIRSHIP_CHANNEL_ID.ordinal
    return constants
  }

  private fun getStoresInstances(stores: java.util.ArrayList<Any>): ArrayList<Store> {
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
    return result
  }

  @ReactMethod
  fun startWithAPIKey(apiKey: String,
                      stores: ReadableArray,
                      userId: String?,
                      logLevel: Int,
                      observerMode: Boolean) {
    val storesInstances = getStoresInstances(stores.toArrayList())

    Purchasely.Builder(reactApplicationContext.applicationContext)
      .apiKey(apiKey)
      .stores(storesInstances)
      .userId(userId)
      .eventListener(eventListener)
      .logLevel(LogLevel.values()[logLevel])
      .observerMode(observerMode)
      .build()

    Purchasely.appTechnology = PLYAppTechnology.REACT_NATIVE

    Purchasely.start()

    Purchasely.purchaseListener = purchaseListener
  }

  @ReactMethod
  fun close() {
    close()
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
  fun isReadyToPurchase(readyToPurchase: Boolean) {
    Purchasely.isReadyToPurchase = readyToPurchase
  }

  @ReactMethod
  fun setAttribute(attribute: Int, value: String) {
    Purchasely.setAttribute(Attribute.values()[attribute], value)
  }

  @ReactMethod
  fun synchronize() {
    Purchasely.synchronize()
  }

  @ReactMethod
  fun presentPresentationWithIdentifier(presentationVendorId: String?,
                                        promise: Promise) {
    purchasePromise = promise
    val intent = Intent(reactApplicationContext.applicationContext, PLYProductActivity::class.java)
    intent.putExtra("presentationId", presentationVendorId)
    reactApplicationContext.currentActivity?.startActivity(intent)
  }

  @ReactMethod
  fun presentProductWithIdentifier(productVendorId: String,
                                    presentationVendorId: String?,
                                    promise: Promise) {
    purchasePromise = promise
    val intent = Intent(reactApplicationContext.applicationContext, PLYProductActivity::class.java)
    intent.putExtra("presentationId", presentationVendorId)
    intent.putExtra("productId", productVendorId)
    reactApplicationContext.currentActivity?.startActivity(intent)
  }

  @ReactMethod
  fun presentPlanWithIdentifier(planVendorId: String,
                                presentationVendorId: String?,
                                promise: Promise) {
    purchasePromise = promise
    val intent = Intent(reactApplicationContext.applicationContext, PLYProductActivity::class.java)
    intent.putExtra("presentationId", presentationVendorId)
    intent.putExtra("planId", planVendorId)
    reactApplicationContext.currentActivity?.startActivity(intent)
  }

  /*@ReactMethod
    public void products(@NonNull Callback failureCallback, @NonNull Callback callback) {
        Purchasely.getProducts(new ProductsListener() {
            @Override
            public void onSuccess(@NotNull List<PLYProduct> list) {
                Log.d("PurchaselyModule", list.size() + " products found");
                ArrayList<ReadableMap> result = new ArrayList<>();
                for (PLYProduct product : list) {
                    result.add(Arguments.makeNativeMap(mapProduct(product)));
                    Log.d("PurchaselyModule", product.toString());
                }
                callback.invoke(Arguments.makeNativeArray(result));
            }

            @Override
            public void onFailure(@NotNull Throwable throwable) {
                Log.e("PurchaselyModule", "Failure", throwable);
                failureCallback.invoke(throwable.getMessage());
            }
        });
    }*/

  @ReactMethod
  fun productWithIdentifier(vendorId: String, promise: Promise) {
    GlobalScope.launch {
      try {
        val product = Purchasely.getProduct(vendorId)
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
        val plan = Purchasely.getPlan(vendorId)
        promise.resolve(Arguments.makeNativeMap(plan?.toMap() ?: emptyMap()))
      } catch (e: Exception) {
        promise.reject(e)
      }
    }
  }

  @ReactMethod
  fun purchaseWithPlanVendorId(planVendorId: String, promise: Promise) {
    GlobalScope.launch {
      try {
        val plan = Purchasely.getPlan(planVendorId)
        if(plan != null) {
          Purchasely.purchase(reactApplicationContext.currentActivity!!,
            plan,
            success = {
              promise.resolve(Arguments.makeNativeMap(it?.toMap() ?: emptyMap()))
            },
            error = {
              promise.reject(it)
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
      success = {
        promise.resolve(true)
      },
      error = {
        promise.reject(it)
      }
    )
  }

  @ReactMethod
  fun displaySubscriptionCancellationInstruction() {
    Purchasely.displaySubscriptionCancellationInstruction(reactApplicationContext.currentActivity as FragmentActivity, 0)
  }

  @ReactMethod
  fun userSubscriptions(promise: Promise) {
    GlobalScope.launch {
      try {
        val subscriptions = Purchasely.getUserSubscriptions()
        val result = ArrayList<ReadableMap?>()
        for (data in subscriptions) {
          result.add(Arguments.makeNativeMap(data.toMap()))
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
  fun handle(deeplink: String?, promise: Promise) {
    if (deeplink == null) {
      promise.reject(IllegalStateException("Deeplink must not be null"))
      return
    }
    val uri = Uri.parse(deeplink)
    promise.resolve(Purchasely.handle(uri))
  }

  private fun sendEvent(reactContext: ReactContext,
                        eventName: String,
                        params: WritableMap?) {
    reactContext
      .getJSModule(RCTDeviceEventEmitter::class.java)
      .emit(eventName, params)
  }

  companion object {
    var purchasePromise: Promise? = null

    fun sendPurchaseResult(result: PLYProductViewResult, plan: PLYPlan?) {
      val productViewResult = when(result) {
        PLYProductViewResult.PURCHASED -> "productResultPurchased"
        PLYProductViewResult.CANCELLED -> "productResultCancelled"
        PLYProductViewResult.RESTORED -> "productResultRestored"
      }

      val map: MutableMap<String, Any?> = HashMap()
      map["result"] = productViewResult
      map["plan"] = plan?.toMap()
      purchasePromise?.resolve(Arguments.makeNativeMap(map))
    }
  }
}
