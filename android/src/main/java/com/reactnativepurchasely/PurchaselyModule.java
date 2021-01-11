package com.reactnativepurchasely;

import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.FragmentActivity;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import org.jetbrains.annotations.NotNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.purchasely.billing.Store;
import io.purchasely.ext.EventListener;
import io.purchasely.ext.LogLevel;
import io.purchasely.ext.PLYProductViewResult;
import io.purchasely.ext.PlanListener;
import io.purchasely.ext.ProductListener;
import io.purchasely.ext.ProductsListener;
import io.purchasely.ext.PurchaseListener;
import io.purchasely.ext.Purchasely;
import io.purchasely.ext.State;
import io.purchasely.ext.SubscriptionsListener;
import io.purchasely.models.PLYPlan;
import io.purchasely.models.PLYProduct;
import io.purchasely.models.PLYSubscriptionData;

public class PurchaselyModule extends ReactContextBaseJavaModule {

    PurchaselyModule(ReactApplicationContext context) {
        super(context);
    }

    EventListener eventListener = event -> {
        //if(plyEvent instanceof PLYEvent.AppInstalled)
        WritableMap params = Arguments.createMap();
        if(event.getProperties() != null) {
            params.putMap(event.getName(), Arguments.makeNativeMap(event.getProperties().toMap()));
        } else {
            params.putString(event.getName(), "");
        }
        sendEvent(getReactApplicationContext(), "Purchasely-Events", params);
    };

    @NotNull
    @Override
    public String getName() {
        return "Purchasely";
    }

    @Nullable
    @Override
    public Map<String, Object> getConstants() {
        final Map<String, Object> constants = new HashMap<>();
        constants.put("logLevelDebug", LogLevel.DEBUG.ordinal());
        constants.put("logLevelWarning", LogLevel.WARNING.ordinal());
        constants.put("logLevelInfo", LogLevel.INFO.ordinal());
        constants.put("logLevelVerbose", LogLevel.VERBOSE.ordinal());
        constants.put("logLevelError", LogLevel.ERROR.ordinal());
        constants.put("productResultPurchased", PLYProductViewResult.PURCHASED.ordinal());
        constants.put("productResultCancelled", PLYProductViewResult.CANCELLED.ordinal());
        constants.put("productResultRestored", PLYProductViewResult.RESTORED.ordinal());
        return constants;
    }

    @ReactMethod
    public void startWithAPIKey(@NonNull String apiKey,
                      @NonNull ReadableArray stores,
                      @Nullable String userId,
                      int logLevel) {
        ArrayList<Store> storesInstances = new ArrayList<>();
        if(stores.toArrayList().contains("Google")
                && Package.getPackage("io.purchasely.google") != null) {
            try {
                storesInstances.add((Store) Class.forName("io.purchasely.google.GoogleStore").newInstance());
                Log.d("Purchasley", "Google Store found");
            } catch (Exception e) {
                Log.e("Purchasely", "Google Store not found :" + e.getMessage(), e);
            }
        }
        if(stores.toArrayList().contains("Huawei")
            && Package.getPackage("io.purchasely.huawei") != null) {
            try {
                storesInstances.add((Store) Class.forName("io.purchasely.huawei.HuaweiStore").newInstance());
            } catch (Exception e) {
                Log.e("Purchasely", e.getMessage(), e);
            }
        }
        new Purchasely.Builder(getReactApplicationContext().getApplicationContext())
                .apiKey(apiKey)
                .stores(storesInstances)
                .userId(userId)
                .eventListener(eventListener)
                .logLevel(LogLevel.values()[logLevel])
                .build();
        Purchasely.start();
    }

    @ReactMethod
    public void close() {
        Purchasely.close();
    }

    @ReactMethod
    public void getAnonymousUserId(@NonNull Callback callback) {
        String anonymousId = Purchasely.getAnonymousUserId();
        Log.d("Anonymous", "Id is " + anonymousId);
        callback.invoke(anonymousId);
    }

    @ReactMethod
    public void setAppUserId(@Nullable String userId) {
        Purchasely.setUserId(userId);
    }

    @ReactMethod
    public void setLogLevel(int logLevel) {
        Purchasely.setLogLevel(LogLevel.values()[logLevel]);
    }

    @ReactMethod
    public void isReadyToPurchase(boolean readyToPurchase) {
        Purchasely.setReadyToPurchase(readyToPurchase);
    }

    @ReactMethod
    public void presentProductWithIdentifier(@NonNull String productVendorId,
                                             @Nullable String presentationVendorId,
                                             @NonNull Callback failureCallback,
                                             @NonNull Callback callback) {
        Intent intent = new Intent(getReactApplicationContext().getApplicationContext(), PLYProductActivity.class);
        intent.putExtra("productId", productVendorId);
        intent.putExtra("presentationId", presentationVendorId);
        getReactApplicationContext().getCurrentActivity().startActivity(intent);
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
    public void productWithIdentifier(@NonNull String vendorId, @NonNull Callback failureCallback, @NonNull Callback callback) {
        Purchasely.getProduct(vendorId, new ProductListener() {
            @Override
            public void onSuccess(@Nullable PLYProduct plyProduct) {
                callback.invoke(Arguments.makeNativeMap(mapProduct(plyProduct)));
            }

            @Override
            public void onFailure(@NotNull Throwable throwable) {
                failureCallback.invoke(throwable.getMessage());
            }
        });
    }

    @ReactMethod
    public void planWithIdentifier(@NonNull String vendorId, @NonNull Callback failureCallback, @NonNull Callback callback) {
        Purchasely.getPlan(vendorId, new PlanListener() {
            @Override
            public void onSuccess(@Nullable PLYPlan plyPlan) {
                callback.invoke(Arguments.makeNativeMap(mapPlan(plyPlan)));
            }

            @Override
            public void onFailure(@NotNull Throwable throwable) {
                failureCallback.invoke(throwable.getMessage());
            }
        });
    }

    @ReactMethod
    public void purchaseWithPlanVendorId(@NonNull String planVendorId, @NonNull Callback failureCallback, @NonNull Callback callback) {
        PurchaseListener listener = state -> {
            if(state instanceof State.PurchaseComplete) {
                Purchasely.setPurchaseListener(null);
                PLYPlan plan = ((State.PurchaseComplete) state).getPlan();
                callback.invoke(Arguments.makeNativeMap((mapPlan(plan))));
            } else if(state instanceof State.RestorationFailed) {
                Purchasely.setPurchaseListener(null);
                failureCallback.invoke("Restoration Failed : " + ((State.RestorationFailed) state).getError().getMessage());
            } else if(state instanceof State.RestorationNoProducts) {
                Purchasely.setPurchaseListener(null);
                callback.invoke(true);
            } else if(state instanceof State.Error) {
                Purchasely.setPurchaseListener(null);
                failureCallback.invoke("Error : " + ((State.Error) state).getError().getMessage());
            }
        };
        Purchasely.getPlan(planVendorId, new PlanListener() {
            @Override
            public void onSuccess(@Nullable PLYPlan plyPlan) {
                Purchasely.purchase(getReactApplicationContext().getCurrentActivity(), plyPlan, listener);
            }

            @Override
            public void onFailure(@NotNull Throwable throwable) {
                failureCallback.invoke(throwable.getMessage());
            }
        });

    }

    @ReactMethod
    public void restoreAllProducts(@NonNull Callback failureCallback, @NonNull Callback callback) {
        PurchaseListener listener = state -> {
            if(state instanceof State.RestorationComplete) {
                Purchasely.setPurchaseListener(null);
                callback.invoke(true);
            } else if(state instanceof State.RestorationFailed) {
                Purchasely.setPurchaseListener(null);
                failureCallback.invoke("Restoration Failed : " + ((State.RestorationFailed) state).getError().getMessage());
            } else if(state instanceof State.RestorationNoProducts) {
                Purchasely.setPurchaseListener(null);
                callback.invoke(true);
            } else if(state instanceof State.Error) {
                Purchasely.setPurchaseListener(null);
                failureCallback.invoke("Error : " + ((State.Error) state).getError().getMessage());
            }
        };
        Purchasely.restoreAllProducts(listener);
    }

    @ReactMethod
    public void displaySubscriptionCancellationInstruction() {
        Purchasely.displaySubscriptionCancellationInstruction((FragmentActivity) getReactApplicationContext().getCurrentActivity(), 0);
    }

    @ReactMethod
    public void userSubscriptions(@NonNull Callback failureCallback, @NonNull Callback callback) {
        Purchasely.getUserSubscriptions(new SubscriptionsListener() {
            @Override
            public void onSuccess(@NotNull List<PLYSubscriptionData> list) {
                ArrayList<ReadableMap> result = new ArrayList<>();
                for (PLYSubscriptionData data : list) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("id", data.getData().getId());
                    map.put("purchaseToken", data.getData().getPurchaseToken());
                    map.put("subscriptionSource", data.getData().getStoreType());
                    map.put("nextRenewalDate", data.getData().getNextRenewalAt());
                    map.put("cancelledDate", data.getData().getCancelledAt());
                    map.put("plan", mapPlan(data.getPlan()));
                    map.put("product", mapProduct(data.getProduct()));
                    result.add(Arguments.makeNativeMap(map));
                    Log.d("PurchaselyModule", data.toString());
                }
                callback.invoke(Arguments.makeNativeArray(result));
            }

            @Override
            public void onFailure(@NotNull Throwable throwable) {
                failureCallback.invoke(throwable.getMessage());
            }
        });
    }

    @ReactMethod
    public void presentSubscriptions() {
        Intent intent = new Intent(getReactApplicationContext().getApplicationContext(), PLYSubscriptionsActivity.class);
        getReactApplicationContext().getCurrentActivity().startActivity(intent);
    }

    @ReactMethod
    public void handle(String deeplink, @NonNull Callback failureCallback, @NonNull Callback callback) {
        if(deeplink == null) {
            failureCallback.invoke("Deeplink must not be null");
            return;
        }

        Uri uri = Uri.parse(deeplink);
        callback.invoke(Purchasely.handle(uri));
    }

    private Map<String, Object> mapPlan(PLYPlan plan) {
        Map<String, Object> map = new HashMap<>();
        if(plan == null) return map;

        map.put("vendorId", plan.getVendorId());
        map.put("name", plan.getName());
        map.put("distributionType", plan.getDistributionType().name());
        map.put("amount", plan.getPrice());
        map.put("priceCurrency", plan.getPriceCurrency());
        map.put("price", plan.localizedFullPrice());
        map.put("period", plan.localizedPeriod());

        map.put("hasIntroductoryPrice", plan.hasIntroductoryPrice());
        map.put("introPrice", plan.localizedFullIntroductoryPrice());
        map.put("introAmount", plan.introductoryPrice());
        map.put("introDuration", plan.localizedIntroductoryDuration());
        map.put("introPeriod", plan.localizedIntroductoryPeriod());

        map.put("hasFreeTrial", plan.hasFreeTrial());

        return map;
    }

    private Map<String, Object> mapProduct(PLYProduct product) {
        Map<String, Object> map = new HashMap<>();
        if(product == null) return map;

        map.put("id", product.getId());
        map.put("name", product.getName());
        map.put("vendorId", product.getVendorId());
        Map<String, Object> plans = new HashMap<>();
        for (PLYPlan plan : product.getPlans()) {
            plans.put(plan.getName(), mapPlan(plan));
        }
        map.put("plans", plans);

        return map;
    }

    private void sendEvent(ReactContext reactContext,
                           String eventName,
                           @Nullable WritableMap params) {
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }

}
