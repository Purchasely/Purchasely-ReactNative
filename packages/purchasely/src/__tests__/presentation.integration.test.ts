/**
 * Integration tests for the cross-platform façade.
 *
 * Validates the JS ↔ native contract documented in
 * `the cross-platform bridge contract`:
 *   - PLYPresentationBuilder → invokes `preloadPresentation`/`displayPresentation` with expected args
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
        removeDefaultPresentationDismissHandler: jest.fn(),
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
    PLYPresentationBuilder,
    setDefaultPresentationDismissHandler,
    removeDefaultPresentationDismissHandler,
} from '../presentation';
import {
    interceptAction,
    removeActionInterceptor,
    removeAllActionInterceptors,
} from '../interceptor';
import { PURCHASELY_PRESENTATION_EVENTS } from '../events';
import { purchaseResultFromOrdinal } from '../presentationTypes';

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

    describe('PLYPresentationBuilder.placement(...).preload()', () => {
        it('invokes preloadPresentation with placementId + contentId payload', async () => {
            const req = PLYPresentationBuilder.placement('home')
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
            const req = PLYPresentationBuilder.placement('home').build();
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

    describe('PLYPresentationBuilder.screen(...).build()', () => {
        it('maps screenId → native presentationId field (bridge mapping P1.1)', () => {
            const req = PLYPresentationBuilder.screen('screen-xyz').build();
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

    describe('PLYPresentationBuilder.default().build()', () => {
        // Contract: `default()` carries no placementId/screenId. Both native
        // bridges resolve the SDK default presentation from that absence — iOS
        // takes its `else if (isDefault)` branch → `fetchPresentationWith:nil`,
        // Android builds an empty builder → `ply_default`. The `isDefault` flag
        // must therefore reach native with null ids; regressing it silently
        // breaks `default()`.
        it('sends isDefault:true with null placement + presentation ids (preload)', () => {
            const req = PLYPresentationBuilder.default().build();
            req.preload();

            expect(native.preloadPresentation).toHaveBeenCalledTimes(1);
            const [, payload] = native.preloadPresentation.mock.calls[0];
            expect(payload.isDefault).toBe(true);
            expect(payload.placementId).toBeNull();
            expect(payload.presentationId).toBeNull();
        });

        it('forwards the same default payload to displayPresentation', () => {
            const req = PLYPresentationBuilder.default().build();
            req.display();

            expect(native.displayPresentation).toHaveBeenCalledTimes(1);
            const [, payload] = native.displayPresentation.mock.calls[0];
            expect(payload.isDefault).toBe(true);
            expect(payload.placementId).toBeNull();
            expect(payload.presentationId).toBeNull();
        });

        it('placement()/screen() do not set isDefault', () => {
            PLYPresentationBuilder.placement('home').build().preload();
            const [, payload] = native.preloadPresentation.mock.calls[0];
            expect(payload.isDefault).toBe(false);
        });
    });

    describe('PLYPresentationBuilder.defaultSource().build()', () => {
        // `defaultSource()` is the canonical cross-platform factory (Flutter
        // parity); `default()` is a kept alias. Both must send isDefault:true
        // with null ids so native resolves the SDK default presentation.
        it('mirrors default(): isDefault:true with null placement + presentation ids', () => {
            const req = PLYPresentationBuilder.defaultSource().build();
            req.preload();

            expect(native.preloadPresentation).toHaveBeenCalledTimes(1);
            const [, payload] = native.preloadPresentation.mock.calls[0];
            expect(payload.isDefault).toBe(true);
            expect(payload.placementId).toBeNull();
            expect(payload.presentationId).toBeNull();
        });
    });

    describe('PLYPresentationBuilder chain modifiers (contentId/backgroundColor/progressColor/displayCloseButton/displayBackButton)', () => {
        it('forwards all builder-configured display options in the preload payload', () => {
            const req = PLYPresentationBuilder.placement('home')
                .contentId('content-1')
                .backgroundColor('#FFFFFF')
                .progressColor('#FF0000')
                .displayCloseButton(false)
                .displayBackButton(true)
                .build();
            req.preload();

            const [, payload] = native.preloadPresentation.mock.calls[0];
            expect(payload).toMatchObject({
                contentId: 'content-1',
                backgroundColor: '#FFFFFF',
                progressColor: '#FF0000',
                displayCloseButton: false,
                displayBackButton: true,
            });
        });

        it('forwards the same options to displayPresentation', () => {
            const req = PLYPresentationBuilder.placement('home')
                .backgroundColor('#000000')
                .displayCloseButton(true)
                .build();
            req.display();

            const [, payload] = native.displayPresentation.mock.calls[0];
            expect(payload).toMatchObject({
                backgroundColor: '#000000',
                displayCloseButton: true,
            });
        });

        it('defaults every optional display option to null when not configured', () => {
            const req = PLYPresentationBuilder.placement('home').build();
            req.preload();

            const [, payload] = native.preloadPresentation.mock.calls[0];
            expect(payload).toMatchObject({
                contentId: null,
                backgroundColor: null,
                progressColor: null,
                displayCloseButton: null,
                displayBackButton: null,
            });
        });
    });

    describe('PLYPresentationBuilder#onLoaded', () => {
        it('invokes the builder-configured onLoaded callback with the presentation and a null error on success', async () => {
            const onLoaded = jest.fn();
            const req = PLYPresentationBuilder.placement('home').onLoaded(onLoaded).build();
            const preloadPromise = req.preload();
            const [requestId] = native.preloadPresentation.mock.calls[0];

            emit(PURCHASELY_PRESENTATION_EVENTS.LOADED, {
                requestId,
                presentation: fakePresentationPayload,
            });
            await preloadPromise;

            expect(onLoaded).toHaveBeenCalledTimes(1);
            const [presentation, error] = onLoaded.mock.calls[0];
            expect(presentation.screenId).toBe('screen-abc');
            expect(error).toBeNull();
        });

        it('forwards the normalized error to onLoaded when LOADED carries one alongside a presentation', async () => {
            const onLoaded = jest.fn();
            const req = PLYPresentationBuilder.placement('home').onLoaded(onLoaded).build();
            req.preload().catch(() => {});
            const [requestId] = native.preloadPresentation.mock.calls[0];

            // Presentation still present — onLoaded fires per contract, error is passed through.
            emit(PURCHASELY_PRESENTATION_EVENTS.LOADED, {
                requestId,
                presentation: fakePresentationPayload,
                error: { message: 'partial failure' },
            });
            await new Promise((r) => setImmediate(r));

            expect(onLoaded).toHaveBeenCalledTimes(1);
            expect(onLoaded.mock.calls[0][1]).toMatchObject({ message: 'partial failure' });
        });

        it('does not invoke onLoaded and rejects preload() when LOADED carries no presentation', async () => {
            const onLoaded = jest.fn();
            const req = PLYPresentationBuilder.placement('home').onLoaded(onLoaded).build();
            const preloadPromise = req.preload();
            const [requestId] = native.preloadPresentation.mock.calls[0];

            emit(PURCHASELY_PRESENTATION_EVENTS.LOADED, {
                requestId,
                presentation: null,
                error: { message: 'no screen' },
            });

            await expect(preloadPromise).rejects.toMatchObject({ message: 'no screen' });
            expect(onLoaded).not.toHaveBeenCalled();
        });
    });

    describe('PLYLoadedPresentation lifecycle delegation', () => {
        it('preload() resolves a presentation that delegates display/close/back to the request', async () => {
            const req = PLYPresentationBuilder.placement('home').build();
            const preloadPromise = req.preload();
            const [requestId] = native.preloadPresentation.mock.calls[0];

            emit(PURCHASELY_PRESENTATION_EVENTS.LOADED, {
                requestId,
                presentation: fakePresentationPayload,
            });

            const loaded = await preloadPromise;
            // Data fields of PLYPresentation are still present.
            expect(loaded.screenId).toBe('screen-abc');
            expect(loaded.placementId).toBe('home');
            // Lifecycle methods added by PLYLoadedPresentation.
            expect(typeof loaded.display).toBe('function');
            expect(typeof loaded.close).toBe('function');
            expect(typeof loaded.back).toBe('function');

            // display() on the loaded presentation drives the same request
            // (same requestId reaches native).
            const displayPromise = loaded.display({ type: 'modal' });
            expect(native.displayPresentation).toHaveBeenCalledTimes(1);
            const [displayRequestId, , transition] =
                native.displayPresentation.mock.calls[0];
            expect(displayRequestId).toBe(requestId);
            expect(transition).toMatchObject({ type: 'modal' });

            emit(PURCHASELY_PRESENTATION_EVENTS.DISMISSED, {
                requestId,
                closeReason: 'programmatic',
            });
            const outcome = await displayPromise;
            expect(outcome.closeReason).toBe('programmatic');

            // close() / back() delegate to the same request id.
            loaded.close();
            expect(native.closePresentation).toHaveBeenCalledWith(requestId);
            loaded.back();
            expect(native.goBackToPreviousScreen).toHaveBeenCalledWith(requestId);
        });

        it('exposes the request id publicly (used by the embedded view)', () => {
            const req = PLYPresentationBuilder.placement('home').build();
            expect(req.requestId).toBeNull();
            req.preload();
            expect(req.requestId).toMatch(/^ply_req_/);
        });
    });

    describe('PLYPresentationRequest#onDismissed / #onPresented / #onCloseRequested (post-build hot-swap)', () => {
        it('request.onDismissed() replaces the callback set on the builder', async () => {
            const builderHandler = jest.fn();
            const req = PLYPresentationBuilder.placement('home')
                .onDismissed(builderHandler)
                .build();

            const hotSwapHandler = jest.fn();
            req.onDismissed(hotSwapHandler);

            const displayPromise = req.display();
            const [requestId] = native.displayPresentation.mock.calls[0];
            emit(PURCHASELY_PRESENTATION_EVENTS.DISMISSED, {
                requestId,
                closeReason: 'button',
            });
            await displayPromise;

            expect(hotSwapHandler).toHaveBeenCalledTimes(1);
            expect(builderHandler).not.toHaveBeenCalled();
        });

        it('request.onPresented() replaces the callback set on the builder', () => {
            const builderHandler = jest.fn();
            const req = PLYPresentationBuilder.placement('home')
                .onPresented(builderHandler)
                .build();

            const hotSwapHandler = jest.fn();
            req.onPresented(hotSwapHandler);

            req.display();
            const [requestId] = native.displayPresentation.mock.calls[0];
            emit(PURCHASELY_PRESENTATION_EVENTS.PRESENTED, {
                requestId,
                presentation: fakePresentationPayload,
            });

            expect(hotSwapHandler).toHaveBeenCalledTimes(1);
            expect(builderHandler).not.toHaveBeenCalled();
        });

        it('request.onCloseRequested() replaces the callback set on the builder', () => {
            const builderHandler = jest.fn();
            const req = PLYPresentationBuilder.placement('home')
                .onCloseRequested(builderHandler)
                .build();

            const hotSwapHandler = jest.fn();
            req.onCloseRequested(hotSwapHandler);

            req.display();
            const [requestId] = native.displayPresentation.mock.calls[0];
            emit(PURCHASELY_PRESENTATION_EVENTS.CLOSE_REQUESTED, { requestId });

            expect(hotSwapHandler).toHaveBeenCalledTimes(1);
            expect(builderHandler).not.toHaveBeenCalled();
        });
    });

    describe('purchaseResultFromOrdinal (exported helper)', () => {
        it('maps the 3 known ordinals to their string form', () => {
            expect(purchaseResultFromOrdinal(0)).toBe('purchased');
            expect(purchaseResultFromOrdinal(1)).toBe('cancelled');
            expect(purchaseResultFromOrdinal(2)).toBe('restored');
        });

        it('returns null for null/undefined input', () => {
            expect(purchaseResultFromOrdinal(null)).toBeNull();
            expect(purchaseResultFromOrdinal(undefined)).toBeNull();
        });

        it('returns null for an out-of-range ordinal', () => {
            expect(purchaseResultFromOrdinal(99)).toBeNull();
        });
    });

    describe('PLYPresentationRequest.display() — outcome 5 fields', () => {
        it('resolves with the full outcome at DISMISS (not at trigger)', async () => {
            let presentedPayload: any = null;
            let closeRequestedFired = false;

            const req = PLYPresentationBuilder.placement('home')
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

        it('forwards the v6 transition dimensions (width/height) to native', () => {
            const req = PLYPresentationBuilder.placement('home').build();
            req.display({
                type: 'drawer',
                height: { type: 'percentage', value: 0.6 },
                width: { type: 'pixel', value: 320 },
                dismissible: false,
            });

            const [, , transition] = native.displayPresentation.mock.calls[0];
            expect(transition).toMatchObject({
                type: 'drawer',
                height: { type: 'percentage', value: 0.6 },
                width: { type: 'pixel', value: 320 },
                dismissible: false,
            });
        });

        it('forwards onPresented(null, error) when PRESENTED carries an error', () => {
            let presentedPayload: any = null;
            const req = PLYPresentationBuilder.placement('home')
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
            const req = PLYPresentationBuilder.placement('home').build();
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
                closeReason: 'backSystem',
            });

            expect(captured).not.toBeNull();
            expect(captured.purchaseResult).toBe('restored');
            expect(captured.closeReason).toBe('backSystem');
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

    // Parity with the Flutter/native routing rule (bridge.dart#_handleOnDismissed):
    // on dismiss, the outcome goes to the request's LOCAL `onDismissed` if set,
    // otherwise to the GLOBAL default dismiss handler. In every case the
    // `display()` promise resolves with the outcome.
    //
    // These mirror the Flutter reference E2E tests:
    //   - default_dismiss_via_display_test.dart (T11): display() with NO local
    //     onDismissed → default handler receives the outcome.
    //   - local_dismiss_handler_test.dart (T12): local onDismissed set →
    //     default handler NOT called.
    describe('display() dismiss routing — default-handler fallback', () => {
        it('(a) no local onDismissed + default set → default receives the outcome AND the promise resolves', async () => {
            const defaultHandler = jest.fn();
            setDefaultPresentationDismissHandler(defaultHandler);
            // The native DEFAULT_DISMISSED registration call is fire-and-forget;
            // the fallback below routes through the per-request DISMISSED event.
            defaultHandler.mockClear();

            // Host displays a presentation itself, without a local onDismissed.
            const req = PLYPresentationBuilder.placement('home').build();
            const displayPromise = req.display();
            const [requestId] = native.displayPresentation.mock.calls[0];

            emit(PURCHASELY_PRESENTATION_EVENTS.DISMISSED, {
                requestId,
                presentation: fakePresentationPayload,
                purchaseResult: 0, // purchased
                closeReason: 'backSystem',
            });

            // The promise still resolves with the full outcome…
            const outcome = await displayPromise;
            expect(outcome.closeReason).toBe('backSystem');
            expect(outcome.purchaseResult).toBe('purchased');
            expect(outcome.presentation?.screenId).toBe('screen-abc');

            // …and the default handler received the same outcome (fallback).
            expect(defaultHandler).toHaveBeenCalledTimes(1);
            const forwarded = defaultHandler.mock.calls[0][0];
            expect(forwarded.closeReason).toBe('backSystem');
            expect(forwarded.purchaseResult).toBe('purchased');
            expect(forwarded.presentation?.screenId).toBe('screen-abc');
        });

        it('(b) local onDismissed + default set → local wins, default NOT called', async () => {
            const defaultHandler = jest.fn();
            const localHandler = jest.fn();
            setDefaultPresentationDismissHandler(defaultHandler);
            defaultHandler.mockClear();

            const req = PLYPresentationBuilder.placement('home')
                .onDismissed(localHandler)
                .build();
            const displayPromise = req.display();
            const [requestId] = native.displayPresentation.mock.calls[0];

            emit(PURCHASELY_PRESENTATION_EVENTS.DISMISSED, {
                requestId,
                presentation: fakePresentationPayload,
                closeReason: 'button',
            });

            const outcome = await displayPromise;
            expect(outcome.closeReason).toBe('button');

            // The local handler received the outcome…
            expect(localHandler).toHaveBeenCalledTimes(1);
            expect(localHandler.mock.calls[0][0].closeReason).toBe('button');
            // …and the default handler stayed silent (local wins).
            expect(defaultHandler).not.toHaveBeenCalled();
        });

        it('(c) neither local onDismissed nor default handler → promise resolves without error', async () => {
            // No default handler registered (beforeEach cleared it) and no local
            // onDismissed: the dismissal must not throw and must still resolve.
            const req = PLYPresentationBuilder.placement('home').build();
            const displayPromise = req.display();
            const [requestId] = native.displayPresentation.mock.calls[0];

            emit(PURCHASELY_PRESENTATION_EVENTS.DISMISSED, {
                requestId,
                presentation: fakePresentationPayload,
                closeReason: 'programmatic',
            });

            const outcome = await displayPromise;
            expect(outcome.closeReason).toBe('programmatic');
            expect(outcome.error).toBeFalsy();
        });

        it('does not double-fire: an SDK-opened DEFAULT_DISMISSED reaches only the default handler, a host display() reaches only its per-request path', async () => {
            const defaultHandler = jest.fn();
            const localHandler = jest.fn();
            setDefaultPresentationDismissHandler(defaultHandler);
            defaultHandler.mockClear();

            // Host-owned presentation with a LOCAL handler.
            const req = PLYPresentationBuilder.placement('home')
                .onDismissed(localHandler)
                .build();
            const displayPromise = req.display();
            const [requestId] = native.displayPresentation.mock.calls[0];

            // SDK-opened dismissal (campaign/deeplink) — carries NO requestId.
            emit(PURCHASELY_PRESENTATION_EVENTS.DEFAULT_DISMISSED, {
                presentation: fakePresentationPayload,
                closeReason: 'backSystem',
            });
            // Host-owned dismissal — carries the request id.
            emit(PURCHASELY_PRESENTATION_EVENTS.DISMISSED, {
                requestId,
                presentation: fakePresentationPayload,
                closeReason: 'button',
            });
            await displayPromise;

            // The default handler fired exactly once — for the SDK-opened event
            // only (the host dismissal was consumed by the local handler).
            expect(defaultHandler).toHaveBeenCalledTimes(1);
            expect(defaultHandler.mock.calls[0][0].closeReason).toBe('backSystem');
            // The local handler fired exactly once — for the host dismissal.
            expect(localHandler).toHaveBeenCalledTimes(1);
            expect(localHandler.mock.calls[0][0].closeReason).toBe('button');
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
                info: {
                    contentId: 'c1',
                    presentation: {
                        ...fakePresentationPayload,
                        audienceId: 'audience-1',
                        abTestId: 'ab-1',
                        abTestVariantId: 'variant-1',
                        campaignId: 'campaign-1',
                        flowId: 'flow-1',
                        metadata: { source: 'interceptor' },
                    },
                },
                payload: { plan: { vendorId: 'monthly' } },
            });

            await new Promise((r) => setImmediate(r));

            expect(handler).toHaveBeenCalledTimes(1);
            const [info, payload] = handler.mock.calls[0];
            expect(info).toMatchObject({
                contentId: 'c1',
                presentation: {
                    screenId: 'screen-abc',
                    placementId: 'home',
                    contentId: 'content-1',
                    audienceId: 'audience-1',
                    abTestId: 'ab-1',
                    abTestVariantId: 'variant-1',
                    campaignId: 'campaign-1',
                    flowId: 'flow-1',
                    language: 'fr',
                    height: 720,
                    metadata: { source: 'interceptor' },
                },
            });
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

        it('removeAllActionInterceptors unregisters every kind that was registered', () => {
            interceptAction('purchase', jest.fn());
            interceptAction('login', jest.fn());
            interceptAction('restore', jest.fn());
            native.unregisterActionInterceptor.mockClear();

            removeAllActionInterceptors();

            expect(native.unregisterActionInterceptor).toHaveBeenCalledWith('purchase');
            expect(native.unregisterActionInterceptor).toHaveBeenCalledWith('login');
            expect(native.unregisterActionInterceptor).toHaveBeenCalledWith('restore');
            expect(native.unregisterActionInterceptor).toHaveBeenCalledTimes(3);
        });

        describe('the 3 PLYInterceptResult outcomes', () => {
            it('propagates an explicit "failed" return to completeActionInterceptor', async () => {
                const handler = jest.fn().mockResolvedValue('failed' as const);
                interceptAction('purchase', handler);

                emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                    requestId: 'req-failed',
                    callbackId: 'cb-failed',
                    kind: 'purchase',
                    info: {},
                    payload: { plan: { vendorId: 'monthly' } },
                });
                await new Promise((r) => setImmediate(r));

                expect(native.completeActionInterceptor).toHaveBeenCalledWith('cb-failed', 'failed');
            });

            it('propagates an explicit "notHandled" return to completeActionInterceptor', async () => {
                const handler = jest.fn().mockResolvedValue('notHandled' as const);
                interceptAction('login', handler);

                emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                    requestId: 'req-nothandled',
                    callbackId: 'cb-nothandled',
                    kind: 'login',
                    info: {},
                });
                await new Promise((r) => setImmediate(r));

                expect(native.completeActionInterceptor).toHaveBeenCalledWith('cb-nothandled', 'notHandled');
            });

            it('maps a handler that throws to "failed" (never lets the rejection escape)', async () => {
                const handler = jest.fn().mockRejectedValue(new Error('boom'));
                interceptAction('restore', handler);

                emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                    requestId: 'req-throw',
                    callbackId: 'cb-throw',
                    kind: 'restore',
                    info: {},
                });
                await new Promise((r) => setImmediate(r));

                expect(handler).toHaveBeenCalledTimes(1);
                expect(native.completeActionInterceptor).toHaveBeenCalledWith('cb-throw', 'failed');
            });
        });

        describe('typed payload normalization per action kind', () => {
            it('navigate: forwards url + title', async () => {
                const handler = jest.fn().mockResolvedValue('success' as const);
                interceptAction('navigate', handler);

                emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                    requestId: 'req-nav',
                    callbackId: 'cb-nav',
                    kind: 'navigate',
                    info: {},
                    payload: { url: 'https://example.com', title: 'Terms' },
                });
                await new Promise((r) => setImmediate(r));

                const [, payload] = handler.mock.calls[0];
                expect(payload).toMatchObject({
                    kind: 'navigate',
                    url: 'https://example.com',
                    title: 'Terms',
                });
            });

            it('close: defaults closeReason to "programmatic" when native omits it', async () => {
                const handler = jest.fn().mockResolvedValue('success' as const);
                interceptAction('close', handler);

                emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                    requestId: 'req-close',
                    callbackId: 'cb-close',
                    kind: 'close',
                    info: {},
                    payload: {},
                });
                await new Promise((r) => setImmediate(r));

                const [, payload] = handler.mock.calls[0];
                expect(payload).toMatchObject({ kind: 'close', closeReason: 'programmatic' });
            });

            it('closeAll: forwards an explicit closeReason', async () => {
                const handler = jest.fn().mockResolvedValue('success' as const);
                interceptAction('closeAll', handler);

                emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                    requestId: 'req-closeall',
                    callbackId: 'cb-closeall',
                    kind: 'closeAll',
                    info: {},
                    payload: { closeReason: 'backSystem' },
                });
                await new Promise((r) => setImmediate(r));

                const [, payload] = handler.mock.calls[0];
                expect(payload).toMatchObject({ kind: 'closeAll', closeReason: 'backSystem' });
            });

            it('openPresentation: reads presentationId, falling back to the legacy `presentation` field', async () => {
                const handler = jest.fn().mockResolvedValue('success' as const);
                interceptAction('openPresentation', handler);

                emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                    requestId: 'req-openpres',
                    callbackId: 'cb-openpres',
                    kind: 'openPresentation',
                    info: {},
                    payload: { presentation: 'screen-legacy' },
                });
                await new Promise((r) => setImmediate(r));

                const [, payload] = handler.mock.calls[0];
                expect(payload).toMatchObject({
                    kind: 'openPresentation',
                    presentationId: 'screen-legacy',
                });
            });

            it('openPlacement: reads placementId, falling back to the legacy `placement` field', async () => {
                const handler = jest.fn().mockResolvedValue('success' as const);
                interceptAction('openPlacement', handler);

                emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                    requestId: 'req-openplacement',
                    callbackId: 'cb-openplacement',
                    kind: 'openPlacement',
                    info: {},
                    payload: { placement: 'home-legacy' },
                });
                await new Promise((r) => setImmediate(r));

                const [, payload] = handler.mock.calls[0];
                expect(payload).toMatchObject({
                    kind: 'openPlacement',
                    placementId: 'home-legacy',
                });
            });

            it('webCheckout: forwards all fields and defaults webCheckoutProvider to "other"', async () => {
                const handler = jest.fn().mockResolvedValue('success' as const);
                interceptAction('webCheckout', handler);

                emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                    requestId: 'req-checkout',
                    callbackId: 'cb-checkout',
                    kind: 'webCheckout',
                    info: {},
                    payload: {
                        url: 'https://checkout.example.com',
                        clientReferenceId: 'client-1',
                        queryParameterKey: 'session_id',
                    },
                });
                await new Promise((r) => setImmediate(r));

                const [, payload] = handler.mock.calls[0];
                expect(payload).toMatchObject({
                    kind: 'webCheckout',
                    url: 'https://checkout.example.com',
                    clientReferenceId: 'client-1',
                    queryParameterKey: 'session_id',
                    webCheckoutProvider: 'other',
                });
            });

            it.each(['login', 'restore', 'promoCode'] as const)(
                '%s: payload is null when native sends no payload',
                async (kind) => {
                    const handler = jest.fn().mockResolvedValue('notHandled' as const);
                    interceptAction(kind, handler);

                    emit(PURCHASELY_PRESENTATION_EVENTS.ACTION_INTERCEPTED, {
                        requestId: `req-${kind}`,
                        callbackId: `cb-${kind}`,
                        kind,
                        info: {},
                    });
                    await new Promise((r) => setImmediate(r));

                    const [, payload] = handler.mock.calls[0];
                    expect(payload).toBeNull();
                }
            );
        });
    });
});
