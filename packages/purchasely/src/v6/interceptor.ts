import { NativeModules } from 'react-native';
import type { EmitterSubscription } from 'react-native';

import {
    PURCHASELY_V6_EVENTS,
    purchaselyV6EventEmitter,
} from './events';
import type { V6InterceptorEvent } from './events';
import type {
    ActionPayload,
    InterceptorHandler,
    InterceptorInfo,
    InterceptResult,
    Presentation,
    PresentationActionKind,
} from './types';

/**
 * Registry of attached interceptors. Keyed by action kind so each kind can be
 * subscribed at most once (matching the Android `interceptAction<T>` semantics).
 */
const interceptorRegistry = new Map<
    PresentationActionKind,
    { subscription: EmitterSubscription; handler: InterceptorHandler }
>();

function normalizeInfo(raw: any): InterceptorInfo {
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
              } as Presentation)
            : null,
    };
}

function normalizePayload(
    kind: PresentationActionKind,
    raw: any
): ActionPayload | null {
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
 * The handler returns an {@link InterceptResult} indicating whether the SDK
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
    kind: PresentationActionKind,
    handler: InterceptorHandler
): void {
    removeActionInterceptor(kind);

    const subscription = purchaselyV6EventEmitter.addListener(
        PURCHASELY_V6_EVENTS.ACTION_INTERCEPTED,
        async (event: V6InterceptorEvent) => {
            if (event.kind !== kind) {
                return;
            }
            const info = normalizeInfo(event.info);
            const payload = normalizePayload(kind, event.payload);
            let result: InterceptResult = 'notHandled';
            try {
                result = await handler(info, payload);
            } catch (e) {
                result = 'failed';
            }
            NativeModules.Purchasely.v6CompleteInterceptor(
                event.callbackId,
                result
            );
        }
    );

    interceptorRegistry.set(kind, { subscription, handler });

    NativeModules.Purchasely.v6RegisterInterceptor(kind);
}

/** Remove a specific action interceptor. */
export function removeActionInterceptor(kind: PresentationActionKind): void {
    const entry = interceptorRegistry.get(kind);
    if (entry) {
        entry.subscription.remove();
        interceptorRegistry.delete(kind);
    }
    NativeModules.Purchasely.v6UnregisterInterceptor(kind);
}

/** Remove every previously-registered action interceptor. */
export function removeAllActionInterceptors(): void {
    for (const kind of Array.from(interceptorRegistry.keys())) {
        removeActionInterceptor(kind);
    }
}
