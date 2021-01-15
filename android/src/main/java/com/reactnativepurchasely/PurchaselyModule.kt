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

class PurchaselyModule internal constructor(context: ReactApplicationContext?) : ReactContextBaseJavaModule(context) {

  private val eventListener: EventListener = object: EventListener {
    override fun onEvent(event: PLYEvent) {
      val params = Arguments.createMap()
      if (event.properties != null) {
        params.putMap(event.name, Arguments.makeNativeMap(event.properties!!.toMap()))
      } else {
        params.putString(event.name, "")
      }
      sendEvent(reactApplicationContext, "Purchasely-Events", params)
    }
  }

  override fun getName(): String {
    return "Purchasely"
  }

  override fun getConstants(): Map<String, Any>? {
    val constants: MutableMap<String, Any> = HashMap()
    constants["logLevelDebug"] = LogLevel.DEBUG.ordinal
    constants["logLevelWarning"] = LogLevel.WARNING.ordinal
    constants["logLevelInfo"] = LogLevel.INFO.ordinal
    constants["logLevelVerbose"] = LogLevel.VERBOSE.ordinal
    constants["logLevelError"] = LogLevel.ERROR.ordinal
    constants["productResultPurchased"] = PLYProductViewResult.PURCHASED.ordinal
    constants["productResultCancelled"] = PLYProductViewResult.CANCELLED.ordinal
    constants["productResultRestored"] = PLYProductViewResult.RESTORED.ordinal
    return constants
  }

  private fun getStoresInstances(stores: java.util.ArrayList<Any>): ArrayList<Store> {
    val result = ArrayList<Store>()
    if (stores.contains("Google")
      && Package.getPackage("io.purchasely.google") != null) {
      try {
        result.add(Class.forName("io.purchasely.google.GoogleStore").newInstance() as Store)
        Log.d("Purchasley", "Google Store found")
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
                      logLevel: Int) {
    val storesInstances = getStoresInstances(stores.toArrayList())

    Purchasely.Builder(reactApplicationContext.applicationContext)
      .apiKey(apiKey)
      .stores(storesInstances)
      .userId(userId)
      .eventListener(eventListener)
      .logLevel(LogLevel.values()[logLevel])
      .build()
      .start()
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
  fun setAppUserId(userId: String?) {
    Purchasely.setUserId(userId)
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
  fun presentProductWithIdentifier(productVendorId: String,
                                   presentationVendorId: String?,
                                   callback: Callback) {
    purchaseCallback = callback
    val intent = Intent(reactApplicationContext.applicationContext, PLYProductActivity::class.java)
    intent.putExtra("productId", productVendorId)
    intent.putExtra("presentationId", presentationVendorId)
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
        promise.resolve(Arguments.makeNativeMap(product.map()))
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
        promise.resolve(Arguments.makeNativeMap(plan.map()))
      } catch (e: Exception) {
        promise.reject(e)
      }
    }
  }

  @ReactMethod
  fun purchaseWithPlanVendorId(planVendorId: String, promise: Promise) {
    val listener = object: PurchaseListener {
      override fun onPurchaseStateChanged(state: State) {
          when(state) {
            is State.PurchaseComplete -> {
                Purchasely.purchaseListener = null
                promise.resolve(Arguments.makeNativeMap(state.plan.map()))
            }
            is State.PurchaseFailed -> {
              Purchasely.purchaseListener = null
              promise.reject(state.error)
            }
            is State.Error -> {
              Purchasely.purchaseListener = null
              promise.reject(state.error)
            }
            else -> {
              //do nothing
            }
          }
      }
    }

    GlobalScope.launch {
      try {
        val plan = Purchasely.getPlan(planVendorId)
        if(plan != null) {
          Purchasely.purchase(reactApplicationContext.currentActivity!!, plan, listener)
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
    val listener = object: PurchaseListener {
      override fun onPurchaseStateChanged(state: State) {
        when(state) {
          is State.RestorationComplete -> {
            Purchasely.purchaseListener = null
            promise.resolve(true)
          }
          is State.RestorationFailed -> {
            Purchasely.purchaseListener = null
            promise.reject(state.error)
          }
          is State.RestorationNoProducts -> {
            Purchasely.purchaseListener = null
            promise.resolve(false)
          }
          is State.Error -> {
            Purchasely.purchaseListener = null
            promise.reject(state.error)
          }
          else -> {
            //do nothing
          }
        }
      }
    }

    Purchasely.restoreAllProducts(listener)
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
          val map: MutableMap<String, Any?> = HashMap()
          map["id"] = data.data.id
          map["purchaseToken"] = data.data.purchaseToken
          map["subscriptionSource"] = data.data.storeType
          map["nextRenewalDate"] = data.data.nextRenewalAt
          map["cancelledDate"] = data.data.cancelledAt
          map["plan"] = data.plan.map()
          map["product"] = data.product.map()
          result.add(Arguments.makeNativeMap(map))
          Log.d("PurchaselyModule", data.toString())
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
    var purchaseCallback: Callback? = null

    fun sendPurchaseResult(result: PLYProductViewResult, plan: PLYPlan?) {
      val productViewResult = when(result) {
        PLYProductViewResult.PURCHASED -> "productResultPurchased"
        PLYProductViewResult.CANCELLED -> "productResultCancelled"
        PLYProductViewResult.RESTORED -> "productResultRestored"
      }

      val map: MutableMap<String, Any?> = HashMap()
      map["result"] = productViewResult
      map["plan"] = plan.map()
      purchaseCallback?.invoke(Arguments.makeNativeMap(map))
    }
  }
}

fun PLYPlan?.map() : Map<String, Any?> {
  val map: MutableMap<String, Any?> = HashMap()
  if (this == null) return map
  map["vendorId"] = this.vendorId
  map["name"] = this.name
  map["distributionType"] = this.distributionType?.name
  map["amount"] = this.getPrice()
  map["priceCurrency"] = this.getPriceCurrency()
  map["price"] = this.localizedFullPrice()
  map["period"] = this.localizedPeriod()
  map["hasIntroductoryPrice"] = this.hasIntroductoryPrice()
  map["introPrice"] = this.localizedFullIntroductoryPrice()
  map["introAmount"] = this.introductoryPrice()
  map["introDuration"] = this.localizedIntroductoryDuration()
  map["introPeriod"] = this.localizedIntroductoryPeriod()
  map["hasFreeTrial"] = this.hasFreeTrial()
  return map
}

fun PLYProduct?.map() : Map<String, Any?> {
  val map: MutableMap<String, Any?> = HashMap()
  if (this == null) return map
  map["id"] = this.id
  map["name"] = this.name
  map["vendorId"] = this.vendorId
  val plans: MutableMap<String?, Any> = HashMap()
  this.plans.forEach { plan ->
    plans[plan.name] = plan.map()
  }
  map["plans"] = plans
  return map
}