import { NativeEventEmitter, NativeModules } from 'react-native';

/**
 * Native event names used for the v6 presentation lifecycle and interceptors.
 * The Android and iOS bridges emit these names with a payload describing the
 * pending request id and call-specific data.
 *
 * @internal
 */
export const PURCHASELY_V6_EVENTS = {
    /** Presentation finished loading (resolves a `preload()` Promise). */
    LOADED: 'PURCHASELY_V6_LOADED',
    /** Presentation became visible to the user (`onPresented` callback). */
    PRESENTED: 'PURCHASELY_V6_PRESENTED',
    /** User requested closing the presentation (`onCloseRequested`). */
    CLOSE_REQUESTED: 'PURCHASELY_V6_CLOSE_REQUESTED',
    /** Presentation dismissed — resolves the `display()` Promise. */
    DISMISSED: 'PURCHASELY_V6_DISMISSED',
    /** Action interceptor fired and is awaiting an InterceptResult. */
    ACTION_INTERCEPTED: 'PURCHASELY_V6_ACTION_INTERCEPTED',
} as const;

/** @internal */
export const purchaselyV6EventEmitter = new NativeEventEmitter(
    NativeModules.Purchasely
);

/** Shape of every v6 lifecycle event payload. */
export interface V6LifecycleEvent {
    requestId: string;
    presentation?: any;
    error?: { code?: string | number | null; message: string; domain?: string | null } | null;
    purchaseResult?: number | null;
    plan?: any;
    closeReason?: 'button' | 'backSystem' | 'programmatic' | null;
}

/** Shape of an interceptor-triggered event sent from native. */
export interface V6InterceptorEvent {
    requestId: string;
    callbackId: string;
    kind: string;
    info?: { contentId?: string | null; presentation?: any | null };
    payload?: any;
}
