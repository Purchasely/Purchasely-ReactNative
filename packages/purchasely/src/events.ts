import { NativeEventEmitter, NativeModules } from 'react-native';

/**
 * Native event names used for the presentation lifecycle and interceptors.
 * The Android and iOS bridges emit these names with a payload describing the
 * pending request id and call-specific data.
 *
 * @internal
 */
export const PURCHASELY_PRESENTATION_EVENTS = {
    /** Presentation finished loading (resolves a `preload()` Promise). */
    LOADED: 'PURCHASELY_PRESENTATION_LOADED',
    /** Presentation became visible to the user (`onPresented` callback). */
    PRESENTED: 'PURCHASELY_PRESENTATION_PRESENTED',
    /** User requested closing the presentation (`onCloseRequested`). */
    CLOSE_REQUESTED: 'PURCHASELY_PRESENTATION_CLOSE_REQUESTED',
    /** Presentation dismissed — resolves the `display()` Promise. */
    DISMISSED: 'PURCHASELY_PRESENTATION_DISMISSED',
    /**
     * A presentation the app did NOT instantiate itself (campaign, deeplink,
     * Promoted In-App Purchase) was dismissed. Drives the global
     * `setDefaultPresentationDismissHandler` callback. Carries no `requestId`.
     */
    DEFAULT_DISMISSED: 'PURCHASELY_DEFAULT_PRESENTATION_DISMISSED',
    /** Action interceptor fired and is awaiting an InterceptResult. */
    ACTION_INTERCEPTED: 'PURCHASELY_ACTION_INTERCEPTED',
} as const;

/** @internal */
export const presentationEventEmitter = new NativeEventEmitter(
    NativeModules.Purchasely
);

/** Shape of every lifecycle event payload. */
export interface PresentationLifecycleEvent {
    requestId: string;
    presentation?: any;
    error?: { code?: string | number | null; message: string; domain?: string | null } | null;
    purchaseResult?: number | null;
    plan?: any;
    closeReason?:
        | 'button'
        | 'backSystem'
        | 'interactiveDismiss'
        | 'programmatic'
        | null;
}

/** Shape of an interceptor-triggered event sent from native. */
export interface ActionInterceptorEvent {
    requestId: string;
    callbackId: string;
    kind: string;
    info?: { contentId?: string | null; presentation?: any | null };
    payload?: any;
}
