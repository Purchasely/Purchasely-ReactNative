import { NativeEventEmitter, NativeModules } from 'react-native';
import type { EmitterSubscription } from 'react-native';

import type { PLYWebRedemptionResult } from './types';

/**
 * Emitter for the Web2App redemption event.
 *
 * Kept in its own module so `startBuilder.ts` can subscribe a listener from
 * the start chain without importing `index.ts`, which would be a cycle.
 *
 * @internal
 */
let redemptionEventEmitter: NativeEventEmitter | undefined;

/**
 * Constructed on first use, not at import time. `startBuilder.ts` imports
 * this module, so an emitter built at module load would be created by every
 * consumer of the builder, whether or not the app listens for a redemption.
 */
const emitter = (): NativeEventEmitter => {
    if (redemptionEventEmitter === undefined) {
        redemptionEventEmitter = new NativeEventEmitter(
            NativeModules.Purchasely
        );
    }
    return redemptionEventEmitter;
};

/**
 * The chain-owned subscription, if any.
 *
 * The builder owns at most one listener. Keeping its handle here is what lets
 * a later `webRedemptionListener(...)` replace an earlier one instead of
 * stacking a second live subscription on the same event.
 *
 * @internal
 */
let builderSubscription: EmitterSubscription | undefined;

/**
 * Register the listener that `PurchaselyBuilder.webRedemptionListener(...)`
 * carries, replacing the one a previous chain registered.
 *
 * Only the chain-owned subscription is removed. A listener the app added with
 * {@link addWebRedemptionListener} is left alone, because that is a separate,
 * app-owned registration with its own lifetime.
 *
 * @internal
 */
/** @internal */
export const WEB_REDEMPTION_EVENT = 'WEB_REDEMPTION_LISTENER';

export type WebRedemptionListenerCallback = (
    result: PLYWebRedemptionResult
) => void;

/**
 * Listen to the outcome of a Web2App redemption
 * (`{scheme}://ply/redeem/{token}`).
 *
 * Prefer `Purchasely.builder(key).webRedemptionListener(cb)`, which subscribes
 * the callback before `start()` runs and cannot be ordered wrongly. Use this
 * function when the app must add or replace the listener after the SDK
 * started, and accept that a redemption which settles during `start()` is
 * then missed.
 *
 * The SDK calls the listener on the main thread, exactly once per settled
 * redemption, on success and on failure alike.
 *
 * The `appHandlesRedemptionAlert` start option decides *when*:
 *
 * - `false` (the default): the SDK shows its own popin and calls the listener
 *   after the user acknowledges it.
 * - `true`: the SDK shows nothing and calls the listener as soon as the
 *   redemption settles. The app must then show its own result screen.
 *
 * Three more behaviours to know:
 *
 * - `result.replay` is `true` when the **server** reports that the token was
 *   redeemed before. The SDK keeps no cache and calls the server on every
 *   attempt, so this is a verdict about the token, not an observation of the
 *   user.
 * - A redemption deeplink is **not** subject to `allowDeeplink`. The native
 *   SDK intercepts `ply/redeem` out of band, before the routing branch that
 *   the gate sits behind.
 * - **On iOS only**, `result.errorMessage` for an expired link can contain a
 *   masked email address, so the app can tell the user where the fresh link
 *   went. The `REDEMPTION_FAILED` event drops it. Show that text to the user.
 *   Do not forward it to an analytics stack or to a crash reporter.
 */
export const addWebRedemptionListener = (
    callback: WebRedemptionListenerCallback
) => {
    return emitter().addListener(WEB_REDEMPTION_EVENT, callback);
};

/**
 * Remove every listener on the redemption event, whoever added it.
 *
 * The chain-owned handle is dropped as well. It has to be: React Native's
 * `removeAllListeners` goes straight to `RCTDeviceEventEmitter` and settles
 * the native count itself, while the per-subscription `remove()` closure is
 * left believing it still owns a listener. Calling that stale `remove()`
 * later would send a second `removeListeners(1)` for a listener already
 * accounted for.
 *
 * On iOS that is not a harmless miscount. `RCTEventEmitter` does
 * `_listenerCount = MAX(_listenerCount - count, 0)` and calls `stopObserving`
 * the moment the count reaches zero, and `stopObserving` clears the bridge's
 * `shouldEmit` flag, which gates EVERY event the module sends. One extra
 * decrement can therefore silence analytics and the presentation lifecycle
 * while their listeners are still registered.
 */
export const removeWebRedemptionListener = () => {
    builderSubscription = undefined;
    return emitter().removeAllListeners(WEB_REDEMPTION_EVENT);
};

export const setBuilderWebRedemptionListener = (
    callback: WebRedemptionListenerCallback
): void => {
    builderSubscription?.remove();
    builderSubscription = addWebRedemptionListener(callback);
};
