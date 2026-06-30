import { NativeModules } from 'react-native';
import type { EmitterSubscription } from 'react-native';

import {
    PURCHASELY_PRESENTATION_EVENTS,
    presentationEventEmitter,
} from './events';
import type { PLYActionInterceptorEvent } from './events';
import type {
    PLYActionPayload,
    PLYActionInterceptorHandler,
    PLYInterceptorInfo,
    PLYInterceptResult,
    PLYPresentation,
    PLYPresentationActionKind,
} from './presentationTypes';

/**
 * Registry of attached interceptors. Keyed by action kind so each kind can be
 * subscribed at most once (matching the Android `interceptAction<T>` semantics).
 */
const interceptorRegistry = new Map<
    PLYPresentationActionKind,
    { subscription: EmitterSubscription; handler: PLYActionInterceptorHandler }
>();

function normalizeInfo(raw: any): PLYInterceptorInfo {
    if (!raw) {
        return {};
    }
    return {
        contentId: raw.contentId ?? null,
        presentation: raw.presentation
            ? ({
                  screenId: raw.presentation.screenId ?? raw.presentation.id,
                  id: raw.presentation.screenId ?? raw.presentation.id,
                  placementId: raw.presentation.placementId ?? null,
                  contentId: raw.presentation.contentId ?? null,
                  type: raw.presentation.type ?? null,
              } as PLYPresentation)
            : null,
    };
}

function normalizePayload(
    kind: PLYPresentationActionKind,
    raw: any
): PLYActionPayload | null {
    if (!raw) {
        if (
            kind === 'login' ||
            kind === 'restore' ||
            kind === 'promoCode' ||
            kind === 'close' ||
            kind === 'closeAll'
        ) {
            return null;
        }
        return null;
    }

    switch (kind) {
        case 'navigate':
            return {
                kind: 'navigate',
                url: raw.url ?? '',
                title: raw.title ?? null,
            };
        case 'purchase':
            return {
                kind: 'purchase',
                plan: raw.plan,
                subscriptionOffer: raw.subscriptionOffer ?? null,
                offer: raw.offer ?? null,
            };
        case 'close':
        case 'closeAll':
            return {
                kind,
                closeReason: raw.closeReason ?? 'programmatic',
            };
        case 'openPresentation':
            return {
                kind: 'openPresentation',
                presentationId: raw.presentationId ?? raw.presentation ?? '',
            };
        case 'openPlacement':
            return {
                kind: 'openPlacement',
                placementId: raw.placementId ?? raw.placement ?? '',
            };
        case 'webCheckout':
            return {
                kind: 'webCheckout',
                url: raw.url ?? '',
                clientReferenceId: raw.clientReferenceId ?? '',
                queryParameterKey: raw.queryParameterKey ?? '',
                webCheckoutProvider: raw.webCheckoutProvider ?? 'other',
            };
        default:
            return null;
    }
}

/**
 * Register a typed interceptor for a given presentation action.
 *
 * The handler returns an {@link PLYInterceptResult} indicating whether the SDK
 * should consider the action handled by the host app.
 *
 * @example
 * ```ts
 * Purchasely.interceptAction('navigate', async ({ presentation }, payload) => {
 *   if (payload?.kind === 'navigate') {
 *     Linking.openURL(payload.url);
 *     return 'success';
 *   }
 *   return 'notHandled';
 * });
 * ```
 */
export function interceptAction(
    kind: PLYPresentationActionKind,
    handler: PLYActionInterceptorHandler
): void {
    removeActionInterceptor(kind);

    const subscription = presentationEventEmitter.addListener(
        PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED,
        async (event: PLYActionInterceptorEvent) => {
            if (event.kind !== kind) {
                return;
            }
            const info = normalizeInfo(event.info);
            const payload = normalizePayload(kind, event.payload);
            let result: PLYInterceptResult = 'notHandled';
            try {
                result = await handler(info, payload);
            } catch (e) {
                result = 'failed';
            }
            NativeModules.Purchasely.completeActionInterceptor(
                event.callbackId,
                result
            );
        }
    );

    interceptorRegistry.set(kind, { subscription, handler });

    NativeModules.Purchasely.registerActionInterceptor(kind);
}

/** Remove a specific action interceptor. */
export function removeActionInterceptor(kind: PLYPresentationActionKind): void {
    const entry = interceptorRegistry.get(kind);
    if (entry) {
        entry.subscription.remove();
        interceptorRegistry.delete(kind);
    }
    NativeModules.Purchasely.unregisterActionInterceptor(kind);
}

/** Remove every previously-registered action interceptor. */
export function removeAllActionInterceptors(): void {
    for (const kind of Array.from(interceptorRegistry.keys())) {
        removeActionInterceptor(kind);
    }
}
