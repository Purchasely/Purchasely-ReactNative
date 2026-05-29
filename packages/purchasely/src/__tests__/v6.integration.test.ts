/**
 * Integration tests for the v6 cross-platform façade.
 *
 * Validates the JS ↔ native contract documented in
 * `reports/v6-presentation-comparison-v3-claude/BRIDGE-CONTRACT.md`:
 *   - PresentationBuilder → invokes `v6Preload`/`v6Display` with expected args
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
        v6Preload: jest.fn().mockResolvedValue(undefined),
        v6Display: jest.fn().mockResolvedValue(undefined),
        v6Close: jest.fn(),
        v6Back: jest.fn(),
        v6RegisterInterceptor: jest.fn(),
        v6UnregisterInterceptor: jest.fn(),
        v6CompleteInterceptor: jest.fn(),
        v6ApplyStartOptions: jest.fn(),
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
    interceptAction,
    removeActionInterceptor,
    PURCHASELY_V6_EVENTS,
} from '../v6';

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

describe('v6 façade · integration with native bridge', () => {
    beforeEach(() => {
        native.v6Preload.mockClear();
        native.v6Display.mockClear();
        native.v6Close.mockClear();
        native.v6Back.mockClear();
        native.v6RegisterInterceptor.mockClear();
        native.v6UnregisterInterceptor.mockClear();
        native.v6CompleteInterceptor.mockClear();
        native.__testResetListeners();
    });

    describe('PresentationBuilder.placement(...).preload()', () => {
        it('invokes v6Preload with placementId + contentId payload', async () => {
            const req = PresentationBuilder.placement('home')
                .contentId('content-1')
                .build();

            const preloadPromise = req.preload();
            // The native call must have been issued synchronously.
            expect(native.v6Preload).toHaveBeenCalledTimes(1);
            const [requestId, payload] = native.v6Preload.mock.calls[0];
            expect(typeof requestId).toBe('string');
            expect(requestId).toMatch(/^v6_req_/);
            expect(payload).toMatchObject({
                placementId: 'home',
                contentId: 'content-1',
            });

            // Simulate native success.
            emit(PURCHASELY_V6_EVENTS.LOADED, {
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
            const [requestId] = native.v6Preload.mock.calls[0];

            emit(PURCHASELY_V6_EVENTS.LOADED, {
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

            expect(native.v6Preload).toHaveBeenCalledTimes(1);
            const [, payload] = native.v6Preload.mock.calls[0];
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

            expect(native.v6Preload).toHaveBeenCalledTimes(1);
            const [, payload] = native.v6Preload.mock.calls[0];
            expect(payload.isDefault).toBe(true);
            expect(payload.placementId).toBeNull();
            expect(payload.presentationId).toBeNull();
        });

        it('forwards the same default payload to v6Display', () => {
            const req = PresentationBuilder.default().build();
            req.display();

            expect(native.v6Display).toHaveBeenCalledTimes(1);
            const [, payload] = native.v6Display.mock.calls[0];
            expect(payload.isDefault).toBe(true);
            expect(payload.placementId).toBeNull();
            expect(payload.presentationId).toBeNull();
        });

        it('placement()/screen() do not set isDefault', () => {
            PresentationBuilder.placement('home').build().preload();
            const [, payload] = native.v6Preload.mock.calls[0];
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
            expect(native.v6Display).toHaveBeenCalledTimes(1);
            const [requestId, , transition] = native.v6Display.mock.calls[0];
            expect(transition).toMatchObject({ type: 'modal' });

            // PRESENTED first — must NOT resolve the display promise
            // (contract P0.3 — bridge waits for DISMISSED).
            emit(PURCHASELY_V6_EVENTS.PRESENTED, {
                requestId,
                presentation: fakePresentationPayload,
            });
            expect(presentedPayload).not.toBeNull();
            expect(presentedPayload.p.screenId).toBe('screen-abc');

            emit(PURCHASELY_V6_EVENTS.CLOSE_REQUESTED, { requestId });
            expect(closeRequestedFired).toBe(true);

            // Now DISMISSED — promise resolves with full outcome.
            emit(PURCHASELY_V6_EVENTS.DISMISSED, {
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
            const [requestId] = native.v6Display.mock.calls[0];

            // Contract P0.4 — error path may carry an error on PRESENTED.
            emit(PURCHASELY_V6_EVENTS.PRESENTED, {
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
            const [requestId] = native.v6Display.mock.calls[0];

            emit(PURCHASELY_V6_EVENTS.DISMISSED, {
                requestId,
                error: { code: 'X', message: 'oops' },
            });

            const outcome = await promise;
            expect(outcome.error).toMatchObject({ code: 'X', message: 'oops' });
            expect(outcome.closeReason).toBeFalsy();
        });
    });

    describe('Action interceptor lifecycle', () => {
        it('registers, dispatches and resolves an interceptor end-to-end', async () => {
            const handler = jest.fn().mockResolvedValue('success' as const);
            interceptAction('purchase', handler);
            expect(native.v6RegisterInterceptor).toHaveBeenCalledWith('purchase');

            emit(PURCHASELY_V6_EVENTS.ACTION_INTERCEPTED, {
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
            expect(native.v6CompleteInterceptor).toHaveBeenCalledWith('cb-1', 'success');
        });

        it('does not auto-resolve orphan events (native must time out)', async () => {
            // No JS interceptor registered for 'restore' — when the native
            // bridge emits the event nobody filters it in, so the bridge layer
            // does NOT post a result back. Native is expected to handle the
            // timeout / default behavior on its side.
            // (Documented as a TODO in the v6 contract — a global JS fallback
            //  could be added later if native does not handle it.)
            emit(PURCHASELY_V6_EVENTS.ACTION_INTERCEPTED, {
                requestId: 'req-2',
                callbackId: 'cb-orphan',
                kind: 'restore',
                info: {},
            });
            await new Promise((r) => setImmediate(r));

            expect(native.v6CompleteInterceptor).not.toHaveBeenCalled();
        });

        it('dispatches only to the matching kind (cross-kind isolation)', async () => {
            const purchaseHandler = jest.fn().mockResolvedValue('success' as const);
            const loginHandler = jest.fn().mockResolvedValue('success' as const);
            interceptAction('purchase', purchaseHandler);
            interceptAction('login', loginHandler);

            emit(PURCHASELY_V6_EVENTS.ACTION_INTERCEPTED, {
                requestId: 'req-3',
                callbackId: 'cb-3',
                kind: 'purchase',
                info: {},
                payload: { plan: { vendorId: 'monthly' } },
            });
            await new Promise((r) => setImmediate(r));

            expect(purchaseHandler).toHaveBeenCalledTimes(1);
            expect(loginHandler).not.toHaveBeenCalled();
            expect(native.v6CompleteInterceptor).toHaveBeenCalledWith('cb-3', 'success');
        });

        it('removeActionInterceptor calls the native unregister', () => {
            interceptAction('login', jest.fn());
            native.v6RegisterInterceptor.mockClear();
            removeActionInterceptor('login');
            expect(native.v6UnregisterInterceptor).toHaveBeenCalledWith('login');
        });
    });
});
