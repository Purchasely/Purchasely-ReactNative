/**
 * Integration tests for the cross-platform façade.
 *
 * Validates the JS ↔ native contract documented in
 * `the cross-platform bridge contract`:
 *   - PresentationBuilder → invokes `preloadPresentation`/`displayPresentation` with expected args
 *   - Lifecycle events (LOADED, PRESENTED, CLOSE_REQUESTED, DISMISSED) flow
 *     through `NativeEventEmitter` and resolve the public promises/callbacks
 *   - Outcome carries the 5 fields (presentation, purchaseResult, plan,
 *     closeReason, error)
 *   - Action interceptor lifecycle: register → trigger → resolve back to native
 */

jest.mock('react-native', () => {
    const listeners: Record<string, Array<(event: any) => void>> = {};
    const emit = (eventName: string, payload: any) => {
        (listeners[eventName] ?? []).forEach((l) => l(payload));
    };

    const Purchasely = {
        getConstants: () => ({
            logLevelDebug: 0,
            logLevelInfo: 1,
            logLevelWarn: 2,
            logLevelError: 3,
            productResultPurchased: 0,
            productResultCancelled: 1,
            productResultRestored: 2,
        }),
        preloadPresentation: jest.fn().mockResolvedValue(undefined),
        displayPresentation: jest.fn().mockResolvedValue(undefined),
        closePresentation: jest.fn(),
        goBackToPreviousScreen: jest.fn(),
        registerActionInterceptor: jest.fn(),
        unregisterActionInterceptor: jest.fn(),
        completeActionInterceptor: jest.fn(),
        setDefaultPresentationDismissHandler: jest.fn(),
        applyStartOptions: jest.fn(),
        start: jest.fn().mockResolvedValue(true),
        readyToOpenDeeplink: jest.fn(),
        addListener: jest.fn(),
        removeListeners: jest.fn(),
        // Exposed only for the integration test — not in production native.
        __testEmit: emit,
        __testResetListeners: () => {
            Object.keys(listeners).forEach((k) => (listeners[k] = []));
        },
    };

    return {
        NativeModules: { Purchasely },
        NativeEventEmitter: jest.fn().mockImplementation(() => ({
            addListener: (name: string, cb: (event: any) => void) => {
                listeners[name] = listeners[name] ?? [];
                listeners[name].push(cb);
                return {
                    remove: () => {
                        listeners[name] = (listeners[name] ?? []).filter((l) => l !== cb);
                    },
                };
            },
            removeAllListeners: (name?: string) => {
                if (name) listeners[name] = [];
            },
        })),
        Platform: { OS: 'ios', select: (obj: any) => obj.ios ?? obj.default },
    };
});

import { NativeModules } from 'react-native';
import {
    PresentationBuilder,
    setDefaultPresentationDismissHandler,
    removeDefaultPresentationDismissHandler,
} from '../presentation';
import { interceptAction, removeActionInterceptor } from '../interceptor';
import { PURCHASELY_PRESENTATION_EVENTS } from '../events';

const native = NativeModules.Purchasely as any;
const emit = native.__testEmit as (e: string, p: any) => void;

const fakePresentationPayload = {
    id: 'screen-abc',
    placementId: 'home',
    contentId: 'content-1',
    type: 'normal',
    height: 720,
    language: 'fr',
    plans: [],
};

describe('façade · integration with native bridge', () => {
    beforeEach(() => {
        native.preloadPresentation.mockClear();
        native.displayPresentation.mockClear();
        native.closePresentation.mockClear();
        native.goBackToPreviousScreen.mockClear();
        native.registerActionInterceptor.mockClear();
        native.unregisterActionInterceptor.mockClear();
        native.completeActionInterceptor.mockClear();
        native.setDefaultPresentationDismissHandler.mockClear();
        native.__testResetListeners();
        // Reset the module-level single-handler state between tests.
        removeDefaultPresentationDismissHandler();
    });

    describe('PresentationBuilder.placement(...).preload()', () => {
        it('invokes preloadPresentation with placementId + contentId payload', async () => {
            const req = PresentationBuilder.placement('home')
                .contentId('content-1')
                .build();

            const preloadPromise = req.preload();
            // The native call must have been issued synchronously.
            expect(native.preloadPresentation).toHaveBeenCalledTimes(1);
            const [requestId, payload] = native.preloadPresentation.mock.calls[0];
            expect(typeof requestId).toBe('string');
            expect(requestId).toMatch(/^ply_req_/);
            expect(payload).toMatchObject({
                placementId: 'home',
                contentId: 'content-1',
            });

            // Simulate native success.
            emit(PURCHASELY_PRESENTATION_EVENTS.LOADED, {
                requestId,
                presentation: fakePresentationPayload,
            });

            const presentation = await preloadPromise;
            expect(presentation.screenId).toBe('screen-abc');
            expect(presentation.placementId).toBe('home');
        });

        it('rejects when native emits LOADED with an error', async () => {
            const req = PresentationBuilder.placement('home').build();
            const preloadPromise = req.preload();
            const [requestId] = native.preloadPresentation.mock.calls[0];

            emit(PURCHASELY_PRESENTATION_EVENTS.LOADED, {
                requestId,
                presentation: null,
                error: { code: 'NET', message: 'offline' },
            });

            await expect(preloadPromise).rejects.toMatchObject({
                code: 'NET',
                message: 'offline',
            });
        });
    });

    describe('PresentationBuilder.screen(...).build()', () => {
        it('maps screenId → native presentationId field (bridge mapping P1.1)', () => {
            const req = PresentationBuilder.screen('screen-xyz').build();
            req.preload();

            expect(native.preloadPresentation).toHaveBeenCalledTimes(1);
            const [, payload] = native.preloadPresentation.mock.calls[0];
            // Contract P1.1 — JS façade uses `screenId`, but the native bridge
            // contract still uses `presentationId` (iOS native API name) until
            // the iOS SDK renames it. The TS layer maps the two transparently.
            expect(payload.presentationId).toBe('screen-xyz');
            expect(payload.placementId).toBeNull();
        });
    });

    describe('PresentationBuilder.default().build()', () => {
        // Contract: `default()` carries no placementId/screenId. Both native
        // bridges resolve the SDK default presentation from that absence — iOS
        // takes its `else if (isDefault)` branch → `fetchPresentationWith:nil`,
        // Android builds an empty builder → `ply_default`. The `isDefault` flag
        // must therefore reach native with null ids; regressing it silently
        // breaks `default()`.
        it('sends isDefault:true with null placement + presentation ids (preload)', () => {
            const req = PresentationBuilder.default().build();
            req.preload();

            expect(native.preloadPresentation).toHaveBeenCalledTimes(1);
            const [, payload] = native.preloadPresentation.mock.calls[0];
            expect(payload.isDefault).toBe(true);
            expect(payload.placementId).toBeNull();
            expect(payload.presentationId).toBeNull();
        });

        it('forwards the same default payload to displayPresentation', () => {
            const req = PresentationBuilder.default().build();
            req.display();

            expect(native.displayPresentation).toHaveBeenCalledTimes(1);
            const [, payload] = native.displayPresentation.mock.calls[0];
            expect(payload.isDefault).toBe(true);
            expect(payload.placementId).toBeNull();
            expect(payload.presentationId).toBeNull();
        });

        it('placement()/screen() do not set isDefault', () => {
            PresentationBuilder.placement('home').build().preload();
            const [, payload] = native.preloadPresentation.mock.calls[0];
            expect(payload.isDefault).toBe(false);
        });
    });

    describe('PresentationRequest.display() — outcome 5 fields', () => {
        it('resolves with the full outcome at DISMISS (not at trigger)', async () => {
            let presentedPayload: any = null;
            let closeRequestedFired = false;

            const req = PresentationBuilder.placement('home')
                .onPresented((p, err) => {
                    presentedPayload = { p, err };
                })
                .onCloseRequested(() => {
                    closeRequestedFired = true;
                })
                .build();

            const displayPromise = req.display({ type: 'modal' });
            expect(native.displayPresentation).toHaveBeenCalledTimes(1);
            const [requestId, , transition] = native.displayPresentation.mock.calls[0];
            expect(transition).toMatchObject({ type: 'modal' });

            // PRESENTED first — must NOT resolve the display promise
            // (contract P0.3 — bridge waits for DISMISSED).
            emit(PURCHASELY_PRESENTATION_EVENTS.PRESENTED, {
                requestId,
                presentation: fakePresentationPayload,
            });
            expect(presentedPayload).not.toBeNull();
            expect(presentedPayload.p.screenId).toBe('screen-abc');

            emit(PURCHASELY_PRESENTATION_EVENTS.CLOSE_REQUESTED, { requestId });
            expect(closeRequestedFired).toBe(true);

            // Now DISMISSED — promise resolves with full outcome.
            emit(PURCHASELY_PRESENTATION_EVENTS.DISMISSED, {
                requestId,
                presentation: fakePresentationPayload,
                purchaseResult: 0, // purchased (ordinal mapping)
                plan: { vendorId: 'plan-monthly' },
                closeReason: 'button',
            });

            const outcome = await displayPromise;
            expect(outcome.purchaseResult).toBe('purchased');
            expect(outcome.closeReason).toBe('button');
            expect(outcome.error).toBeFalsy();
            expect(outcome.presentation?.screenId).toBe('screen-abc');
            expect(outcome.plan).toMatchObject({ vendorId: 'plan-monthly' });
        });

        it('forwards onPresented(null, error) when PRESENTED carries an error', () => {
            let presentedPayload: any = null;
            const req = PresentationBuilder.placement('home')
                .onPresented((p, err) => {
                    presentedPayload = { p, err };
                })
                .build();
            req.display();
            const [requestId] = native.displayPresentation.mock.calls[0];

            // Contract P0.4 — error path may carry an error on PRESENTED.
            emit(PURCHASELY_PRESENTATION_EVENTS.PRESENTED, {
                requestId,
                presentation: null,
                error: { message: 'render failed' },
            });

            expect(presentedPayload.p).toBeNull();
            expect(presentedPayload.err).toMatchObject({ message: 'render failed' });
        });

        it('returns an outcome.error envelope when DISMISSED carries an error', async () => {
            const req = PresentationBuilder.placement('home').build();
            const promise = req.display();
            const [requestId] = native.displayPresentation.mock.calls[0];

            emit(PURCHASELY_PRESENTATION_EVENTS.DISMISSED, {
                requestId,
                error: { code: 'X', message: 'oops' },
            });

            const outcome = await promise;
            expect(outcome.error).toMatchObject({ code: 'X', message: 'oops' });
            expect(outcome.closeReason).toBeFalsy();
        });
    });

    describe('setDefaultPresentationDismissHandler (global handler)', () => {
        it('registers natively and delivers the rich outcome of an SDK-owned presentation', () => {
            let captured: any = null;
            setDefaultPresentationDismissHandler((outcome) => {
                captured = outcome;
            });

            // JS asks native to (re)register its single global handler.
            expect(native.setDefaultPresentationDismissHandler).toHaveBeenCalledTimes(1);

            // A campaign / deeplink screen the app never instantiated is dismissed.
            // The event carries NO requestId — the SDK owns the presentation.
            emit(PURCHASELY_PRESENTATION_EVENTS.DEFAULT_DISMISSED, {
                presentation: fakePresentationPayload,
                purchaseResult: 2, // restored (ordinal mapping)
                plan: { vendorId: 'plan-monthly' },
                closeReason: 'interactiveDismiss',
            });

            expect(captured).not.toBeNull();
            expect(captured.purchaseResult).toBe('restored');
            expect(captured.closeReason).toBe('interactiveDismiss');
            expect(captured.plan).toMatchObject({ vendorId: 'plan-monthly' });
            // `presentation` is always populated so the app can identify the screen.
            expect(captured.presentation?.screenId).toBe('screen-abc');
            expect(captured.error).toBeFalsy();
        });

        it('keeps a single active handler — re-registering replaces the previous one', () => {
            const first = jest.fn();
            const second = jest.fn();
            setDefaultPresentationDismissHandler(first);
            setDefaultPresentationDismissHandler(second);

            emit(PURCHASELY_PRESENTATION_EVENTS.DEFAULT_DISMISSED, {
                presentation: fakePresentationPayload,
                purchaseResult: 1, // cancelled
                closeReason: 'button',
            });

            expect(first).not.toHaveBeenCalled();
            expect(second).toHaveBeenCalledTimes(1);
            expect(native.setDefaultPresentationDismissHandler).toHaveBeenCalledTimes(2);
        });

        it('removeDefaultPresentationDismissHandler stops further deliveries', () => {
            const handler = jest.fn();
            setDefaultPresentationDismissHandler(handler);
            removeDefaultPresentationDismissHandler();

            emit(PURCHASELY_PRESENTATION_EVENTS.DEFAULT_DISMISSED, {
                presentation: fakePresentationPayload,
                closeReason: 'programmatic',
            });

            expect(handler).not.toHaveBeenCalled();
        });
    });

    describe('Action interceptor lifecycle', () => {
        it('registers, dispatches and resolves an interceptor end-to-end', async () => {
            const handler = jest.fn().mockResolvedValue('success' as const);
            interceptAction('purchase', handler);
            expect(native.registerActionInterceptor).toHaveBeenCalledWith('purchase');

            emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                requestId: 'req-1',
                callbackId: 'cb-1',
                kind: 'purchase',
                info: { contentId: 'c1' },
                payload: { plan: { vendorId: 'monthly' } },
            });

            await new Promise((r) => setImmediate(r));

            expect(handler).toHaveBeenCalledTimes(1);
            const [info, payload] = handler.mock.calls[0];
            expect(info).toMatchObject({ contentId: 'c1' });
            expect(payload).toMatchObject({
                kind: 'purchase',
                plan: { vendorId: 'monthly' },
            });
            expect(native.completeActionInterceptor).toHaveBeenCalledWith('cb-1', 'success');
        });

        it('does not auto-resolve orphan events (native must time out)', async () => {
            // No JS interceptor registered for 'restore' — when the native
            // bridge emits the event nobody filters it in, so the bridge layer
            // does NOT post a result back. Native is expected to handle the
            // timeout / default behavior on its side.
            // (Documented as a TODO in the bridge contract — a global JS fallback
            //  could be added later if native does not handle it.)
            emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                requestId: 'req-2',
                callbackId: 'cb-orphan',
                kind: 'restore',
                info: {},
            });
            await new Promise((r) => setImmediate(r));

            expect(native.completeActionInterceptor).not.toHaveBeenCalled();
        });

        it('dispatches only to the matching kind (cross-kind isolation)', async () => {
            const purchaseHandler = jest.fn().mockResolvedValue('success' as const);
            const loginHandler = jest.fn().mockResolvedValue('success' as const);
            interceptAction('purchase', purchaseHandler);
            interceptAction('login', loginHandler);

            emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                requestId: 'req-3',
                callbackId: 'cb-3',
                kind: 'purchase',
                info: {},
                payload: { plan: { vendorId: 'monthly' } },
            });
            await new Promise((r) => setImmediate(r));

            expect(purchaseHandler).toHaveBeenCalledTimes(1);
            expect(loginHandler).not.toHaveBeenCalled();
            expect(native.completeActionInterceptor).toHaveBeenCalledWith('cb-3', 'success');
        });

        it('removeActionInterceptor calls the native unregister', () => {
            interceptAction('login', jest.fn());
            native.registerActionInterceptor.mockClear();
            removeActionInterceptor('login');
            expect(native.unregisterActionInterceptor).toHaveBeenCalledWith('login');
        });
    });
});
