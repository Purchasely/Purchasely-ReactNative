import { NativeModules } from 'react-native';
import type { EmitterSubscription } from 'react-native';

import type {
    PLYLoadedPresentation,
    PLYPresentation,
    PLYPresentationError,
    PLYPresentationOutcome,
    PLYTransition,
} from './presentationTypes';
import { normalizePlan, purchaseResultFromOrdinal } from './presentationTypes';
import { PURCHASELY_PRESENTATION_EVENTS, presentationEventEmitter } from './events';
import type { PLYPresentationLifecycleEvent } from './events';

/** Counter for generating bridge request ids. */
let nextRequestId = 0;
const generateRequestId = (): string => {
    nextRequestId += 1;
    return `ply_req_${Date.now()}_${nextRequestId}`;
};

/** Normalize a native presentation payload to the {@link PLYPresentation} shape. */
function normalizePresentation(raw: any): PLYPresentation | null {
    if (!raw || typeof raw !== 'object') {
        return null;
    }

    // The native bridges emit `id` to stay backwards-compatible.
    // We map it to `screenId` (cf. P1.1).
    const screenId = raw.screenId ?? raw.id;
    if (!screenId) {
        return null;
    }

    return {
        screenId,
        id: screenId,
        placementId: raw.placementId ?? null,
        contentId: raw.contentId ?? null,
        audienceId: raw.audienceId ?? null,
        abTestId: raw.abTestId ?? null,
        abTestVariantId: raw.abTestVariantId ?? null,
        campaignId: raw.campaignId ?? null,
        flowId: raw.flowId ?? null,
        language: raw.language ?? null,
        type: raw.type ?? null,
        plans: raw.plans ?? null,
        metadata: raw.metadata ?? null,
        height: raw.height ?? null,
    };
}

/** Normalize a native error payload to the {@link PLYPresentationError} shape. */
function normalizeError(raw: any): PLYPresentationError | null {
    if (!raw) {
        return null;
    }
    if (typeof raw === 'string') {
        return { message: raw };
    }
    return {
        code: raw.code ?? null,
        message: raw.message ?? 'Unknown error',
        domain: raw.domain ?? null,
    };
}

/** Convert a native lifecycle event into a {@link PLYPresentationOutcome}. */
function eventToOutcome(
    event: PLYPresentationLifecycleEvent,
    presentation: PLYPresentation | null
): PLYPresentationOutcome {
    const error = normalizeError(event.error);
    return {
        presentation,
        purchaseResult: purchaseResultFromOrdinal(event.purchaseResult),
        // [rc.4 hardening] tolerate Android's upcoming DistributionType
        // string for plan.type alongside the numeric ordinal.
        plan: normalizePlan(event.plan) ?? null,
        // Exclusion rule (cf. contract): error != null ⇒ closeReason == null.
        closeReason: error ? null : event.closeReason ?? null,
        error,
    };
}

/**
 * The currently registered global default-dismiss handler — the actual JS
 * callback, kept at module scope separately from its native subscription (see
 * {@link setDefaultPresentationDismissHandler} below).
 *
 * A live reference is needed here (not just the subscription) so a
 * host-initiated `display()` whose request has **no** local `onDismissed` can
 * fall back to it. This mirrors the Flutter/native routing rule
 * (`bridge.dart#_handleOnDismissed`): on dismiss, route the outcome to the
 * request's local `onDismissed` if present, otherwise to the global default
 * handler. `null` when no default handler is registered.
 */
let currentDefaultDismissHandler:
    | ((outcome: PLYPresentationOutcome) => void)
    | null = null;

/**
 * Holds the callbacks registered on a {@link PLYPresentationBuilder}. They are
 * shared between the builder, the request and the live {@link PLYPresentation}
 * so that callbacks reassigned after `preload()` take effect.
 */
interface PresentationCallbacks {
    onLoaded?: (
        presentation: PLYPresentation,
        error?: PLYPresentationError | null
    ) => void;
    onPresented?: (
        presentation?: PLYPresentation | null,
        error?: PLYPresentationError | null
    ) => void;
    onCloseRequested?: () => void;
    onDismissed?: (outcome: PLYPresentationOutcome) => void;
}

interface BuilderConfig {
    placementId?: string | null;
    screenId?: string | null;
    isDefault?: boolean;
    contentId?: string | null;
    backgroundColor?: string | null;
    progressColor?: string | null;
    displayCloseButton?: boolean | null;
    displayBackButton?: boolean | null;
    callbacks: PresentationCallbacks;
}

/**
 * Cross-platform builder. Mirrors the Android/iOS builder API while hiding
 * the platform-specific bridge wiring.
 *
 * @example
 * ```ts
 * const request = PLYPresentationBuilder.placement('ONBOARDING')
 *   .onDismissed((outcome) => console.log(outcome))
 *   .build();
 *
 * const outcome = await request.display();
 * ```
 */
export class PLYPresentationBuilder {
    /** @internal */
    private readonly config: BuilderConfig;

    private constructor(config: BuilderConfig) {
        this.config = config;
    }

    /** Build a request that targets a placement vendor id. */
    static placement(placementId: string): PLYPresentationBuilder {
        return new PLYPresentationBuilder({
            placementId,
            callbacks: {},
        });
    }

    /**
     * Build a request that targets a specific presentation by its screen id.
     * On iOS this maps to `PLYPresentationBuilder.from(presentationId:)`.
     */
    static screen(screenId: string): PLYPresentationBuilder {
        return new PLYPresentationBuilder({
            screenId,
            callbacks: {},
        });
    }

    /**
     * Build a request that uses the SDK's default placement.
     *
     * This is the canonical cross-platform factory (matches the Flutter SDK's
     * `PLYPresentationBuilder.defaultSource()`). The {@link default} alias is
     * kept for parity with the iOS native API.
     */
    static defaultSource(): PLYPresentationBuilder {
        return new PLYPresentationBuilder({
            isDefault: true,
            callbacks: {},
        });
    }

    /**
     * Alias of {@link defaultSource} kept for parity with the iOS native API
     * (which names this factory `default`). Prefer {@link defaultSource} as the
     * canonical cross-platform name.
     */
    static default(): PLYPresentationBuilder {
        return PLYPresentationBuilder.defaultSource();
    }

    contentId(id: string | null): this {
        this.config.contentId = id;
        return this;
    }

    backgroundColor(hex: string | null): this {
        this.config.backgroundColor = hex;
        return this;
    }

    progressColor(hex: string | null): this {
        this.config.progressColor = hex;
        return this;
    }

    /**
     * Toggle the paywall's close button.
     *
     * - **Android** — full toggle: `true` shows the button, `false` hides it.
     * - **iOS** — removal only: only `false` has an effect (it hides the
     *   button). Passing `true` is a no-op — the button follows the paywall's
     *   own configuration.
     */
    displayCloseButton(show: boolean): this {
        this.config.displayCloseButton = show;
        return this;
    }

    /**
     * Toggle the paywall's back button.
     *
     * - **Android** — full toggle: `true` shows the button, `false` hides it.
     * - **iOS** — removal only: only `false` has an effect (it hides the
     *   button). Passing `true` is a no-op — the button follows the paywall's
     *   own configuration.
     */
    displayBackButton(show: boolean): this {
        this.config.displayBackButton = show;
        return this;
    }

    onLoaded(
        handler: (
            presentation: PLYPresentation,
            error?: PLYPresentationError | null
        ) => void
    ): this {
        this.config.callbacks.onLoaded = handler;
        return this;
    }

    onPresented(
        handler: (
            presentation?: PLYPresentation | null,
            error?: PLYPresentationError | null
        ) => void
    ): this {
        this.config.callbacks.onPresented = handler;
        return this;
    }

    /**
     * Register a callback for when the native SDK requests a close on its own
     * (native close button, swipe, hardware back) — never for a programmatic
     * {@link PLYPresentationRequest.close}. See
     * {@link PLYPresentationRequest.onCloseRequested} for the full contract.
     */
    onCloseRequested(handler: () => void): this {
        this.config.callbacks.onCloseRequested = handler;
        return this;
    }

    onDismissed(handler: (outcome: PLYPresentationOutcome) => void): this {
        this.config.callbacks.onDismissed = handler;
        return this;
    }

    /** Convert the builder into a runnable {@link PLYPresentationRequest}. */
    build(): PLYPresentationRequest {
        return new PLYPresentationRequest(this.config);
    }
}

/**
 * Closure(s) needed to settle the promise of whichever `preload()` /
 * `display()` call is currently in flight on a {@link PLYPresentationRequest}.
 * Kept so a later `preload()`/`display()` on the same request can settle the
 * previous one as "superseded" instead of leaving it pending forever (see
 * {@link PLYPresentationRequest.teardownSubscriptions}).
 */
type PendingSettler =
    | { kind: 'preload'; reject: (error: PLYPresentationError) => void }
    | { kind: 'display'; resolve: (outcome: PLYPresentationOutcome) => void };

/**
 * Encapsulates a presentation request: it can be preloaded (without UI),
 * or displayed (which resolves at dismiss).
 */
export class PLYPresentationRequest {
    /** @internal */
    private readonly config: BuilderConfig;
    /** @internal */
    private _requestId: string | null = null;
    /** @internal */
    private subscriptions: EmitterSubscription[] = [];
    /** @internal */
    private livePresentation: PLYPresentation | null = null;
    /** @internal */
    private pendingSettler: PendingSettler | null = null;

    constructor(config: BuilderConfig) {
        this.config = config;
    }

    /**
     * The bridge request id assigned to this request, or `null` before the
     * first `preload()` / `display()`. Consumed by the embedded presentation
     * view to correlate native lifecycle events.
     */
    get requestId(): string | null {
        return this._requestId;
    }

    /**
     * Preload the presentation. Resolves once the SDK reports the screen
     * is loaded (`onLoaded`). Rejects if the SDK fails before load.
     *
     * @remarks
     * Calling `preload()` or `display()` again on the same request before
     * this one settles supersedes it — see {@link display}'s remarks.
     */
    preload(): Promise<PLYLoadedPresentation> {
        const requestId = this.ensureRequestId();

        // Settle whatever preload()/display() is still pending on this
        // request as "superseded" before starting a fresh one.
        this.teardownSubscriptions();

        return new Promise<PLYLoadedPresentation>((resolve, reject) => {
            // Captured locally so late-arriving native/event callbacks can
            // tell whether THEY are still the pending operation before
            // touching any shared state — see the guards below.
            const settler: PendingSettler = { kind: 'preload', reject };
            this.pendingSettler = settler;
            const loadedSubscription =
                presentationEventEmitter.addListener(
                    PURCHASELY_PRESENTATION_EVENTS.LOADED,
                    (event: PLYPresentationLifecycleEvent) => {
                        if (event.requestId !== requestId) {
                            return;
                        }
                        if (this.pendingSettler !== settler) {
                            // Superseded by a newer preload()/display() —
                            // this promise already settled, no-op.
                            return;
                        }
                        loadedSubscription.remove();
                        this.pendingSettler = null;
                        const presentation = normalizePresentation(
                            event.presentation
                        );
                        const error = normalizeError(event.error);
                        if (this.config.callbacks.onLoaded && presentation) {
                            this.config.callbacks.onLoaded(presentation, error);
                        }
                        if (error || !presentation) {
                            reject(error ?? { message: 'Preload failed' });
                            return;
                        }
                        this.livePresentation = presentation;
                        resolve(this.buildLoadedPresentation(presentation));
                    }
                );
            this.subscriptions.push(loadedSubscription);

            NativeModules.Purchasely.preloadPresentation(
                requestId,
                this.toNativePayload()
            ).catch((nativeError: any) => {
                if (this.pendingSettler !== settler) {
                    // A later preload()/display() already superseded this
                    // one — this rejection is stale and must not tear down
                    // the successor's listeners or invoke any callback.
                    return;
                }
                loadedSubscription.remove();
                this.pendingSettler = null;
                reject(normalizeError(nativeError));
            });
        });
    }

    /**
     * Display the presentation. Resolves at DISMISS with a
     * {@link PLYPresentationOutcome} (cf. contract P0.3). Subscribers can attach
     * their own `onPresented` / `onCloseRequested` callbacks via the builder.
     *
     * @remarks
     * Calling `display()` (or `preload()`) again on the same request while a
     * previous `preload()`/`display()` is still pending supersedes it instead
     * of leaving it pending forever: a pending `preload()` **rejects** with a
     * `{ message }` error naming the supersession; a pending `display()`
     * **resolves** with a synthetic {@link PLYPresentationOutcome} whose
     * `error.message` names it (`display()` never rejects — that contract
     * holds here too). Neither case invokes the request's callbacks
     * (`onLoaded` / `onDismissed` / the default handler) — only the promise
     * settles.
     */
    display(transition?: PLYTransition | null): Promise<PLYPresentationOutcome> {
        const requestId = this.ensureRequestId();

        // Settle whatever preload()/display() is still pending on this
        // request as "superseded" before starting a fresh one.
        this.teardownSubscriptions();

        return new Promise<PLYPresentationOutcome>((resolve) => {
            // Captured locally so late-arriving native/event callbacks can
            // tell whether THEY are still the pending operation before
            // touching any shared state — see the guards below.
            const settler: PendingSettler = { kind: 'display', resolve };
            this.pendingSettler = settler;
            this.bindLifecycleEvents(requestId, resolve, settler);

            NativeModules.Purchasely.displayPresentation(
                requestId,
                this.toNativePayload(),
                transition ?? null
            ).catch((nativeError: any) => {
                if (this.pendingSettler !== settler) {
                    // A later preload()/display() already superseded this
                    // one — this rejection is stale and must not invoke this
                    // operation's callbacks or tear down the successor's
                    // listeners/state.
                    return;
                }
                const error = normalizeError(nativeError);
                // Synthesize an outcome so consumers always receive one.
                const outcome: PLYPresentationOutcome = {
                    presentation: this.livePresentation,
                    purchaseResult: null,
                    plan: null,
                    closeReason: null,
                    error: error ?? { message: 'Display failed' },
                };
                if (this.config.callbacks.onPresented) {
                    this.config.callbacks.onPresented(null, outcome.error);
                }
                // Same routing as the DISMISSED path: local `onDismissed` wins,
                // otherwise fall back to the global default dismiss handler.
                if (this.config.callbacks.onDismissed) {
                    this.config.callbacks.onDismissed(outcome);
                } else if (currentDefaultDismissHandler) {
                    currentDefaultDismissHandler(outcome);
                }
                this.pendingSettler = null;
                resolve(outcome);
                this.teardownSubscriptions();
            });
        });
    }

    /**
     * Replace the dismissed-callback after `preload()` / `display()`. Useful
     * for hot-swapping callbacks on a cached {@link PLYPresentation}.
     */
    onDismissed(
        handler: (outcome: PLYPresentationOutcome) => void
    ): this {
        this.config.callbacks.onDismissed = handler;
        return this;
    }

    onPresented(
        handler: (
            presentation?: PLYPresentation | null,
            error?: PLYPresentationError | null
        ) => void
    ): this {
        this.config.callbacks.onPresented = handler;
        return this;
    }

    /**
     * Register a callback for a native close request: the native SDK asking
     * to close on its own (tap the native close button, swipe, hardware
     * back). Purely informational — it does not gate the dismissal, and
     * `onDismissed` still fires right after with the final outcome.
     *
     * @remarks
     * Never fires for a programmatic {@link PLYPresentationRequest.close}:
     * both native bridges clear this callback before closing, so a
     * JS-initiated close goes straight to `onDismissed` without looping back
     * here.
     */
    onCloseRequested(handler: () => void): this {
        this.config.callbacks.onCloseRequested = handler;
        return this;
    }

    /**
     * Programmatically close the presentation if it is currently visible.
     *
     * @remarks
     * **iOS** closes the specific presentation identified by its `requestId`
     * (falling back to closing all Purchasely screens when the request is no
     * longer tracked). **Android** does not yet expose a per-request close, so
     * it dismisses **all** displayed presentations, not only this request. If
     * your app stacks presentations (e.g. a product page inside an onboarding
     * flow), calling `close()` on one will also dismiss the others on Android.
     */
    close(): void {
        if (!this._requestId) {
            return;
        }
        NativeModules.Purchasely.closePresentation(this._requestId);
    }

    /** Navigate back inside a multi-step (Flow) presentation. */
    back(): void {
        if (!this._requestId) {
            return;
        }
        NativeModules.Purchasely.goBackToPreviousScreen(this._requestId);
    }

    private ensureRequestId(): string {
        if (!this._requestId) {
            this._requestId = generateRequestId();
        }
        return this._requestId;
    }

    /**
     * Wrap the loaded {@link PLYPresentation} data with the lifecycle methods
     * (`display` / `close` / `back`), all delegating to this request. Mirrors
     * the Flutter SDK, where `preload()` resolves a presentation that drives
     * its own lifecycle.
     */
    private buildLoadedPresentation(
        presentation: PLYPresentation
    ): PLYLoadedPresentation {
        return {
            ...presentation,
            display: (transition?: PLYTransition | null) =>
                this.display(transition),
            close: () => this.close(),
            back: () => this.back(),
        };
    }

    private bindLifecycleEvents(
        requestId: string,
        resolve: (outcome: PLYPresentationOutcome) => void,
        settler: PendingSettler
    ): void {
        const onPresented = presentationEventEmitter.addListener(
            PURCHASELY_PRESENTATION_EVENTS.PRESENTED,
            (event: PLYPresentationLifecycleEvent) => {
                if (event.requestId !== requestId) {
                    return;
                }
                const presentation =
                    normalizePresentation(event.presentation) ??
                    this.livePresentation;
                if (presentation) {
                    this.livePresentation = presentation;
                }
                const error = normalizeError(event.error);
                if (this.config.callbacks.onPresented) {
                    this.config.callbacks.onPresented(
                        presentation,
                        error ?? null
                    );
                }
            }
        );
        const onCloseRequested = presentationEventEmitter.addListener(
            PURCHASELY_PRESENTATION_EVENTS.CLOSE_REQUESTED,
            (event: PLYPresentationLifecycleEvent) => {
                if (event.requestId !== requestId) {
                    return;
                }
                if (this.config.callbacks.onCloseRequested) {
                    this.config.callbacks.onCloseRequested();
                }
            }
        );
        const onDismissed = presentationEventEmitter.addListener(
            PURCHASELY_PRESENTATION_EVENTS.DISMISSED,
            (event: PLYPresentationLifecycleEvent) => {
                if (event.requestId !== requestId) {
                    return;
                }
                if (this.pendingSettler !== settler) {
                    // Superseded by a newer preload()/display() — this
                    // promise already settled, no-op.
                    return;
                }
                const presentation =
                    normalizePresentation(event.presentation) ??
                    this.livePresentation;
                const outcome = eventToOutcome(event, presentation);
                // Routing (parity with Flutter `_handleOnDismissed` / native):
                // prefer the request's local `onDismissed`; when none is set,
                // fall back to the global default dismiss handler so a
                // fire-and-forget `display()` (no local handler, promise not
                // awaited) still delivers its outcome centrally. The promise
                // ALWAYS resolves with the outcome regardless of routing.
                //
                // Anti-double-fire: the native DEFAULT_DISMISSED event — which
                // also routes to the global handler (see
                // setDefaultPresentationDismissHandler) — is emitted ONLY for
                // SDK-opened presentations (campaign / deeplink / Promoted
                // IAP). Those carry no `requestId` and have no JS request, so
                // they never match this per-request DISMISSED branch. A given
                // dismissal therefore reaches the default handler through
                // exactly one path.
                if (this.config.callbacks.onDismissed) {
                    this.config.callbacks.onDismissed(outcome);
                } else if (currentDefaultDismissHandler) {
                    currentDefaultDismissHandler(outcome);
                }
                this.pendingSettler = null;
                resolve(outcome);
                this.teardownSubscriptions();
            }
        );

        this.subscriptions.push(onPresented, onCloseRequested, onDismissed);
    }

    /**
     * Settle whatever `preload()`/`display()` is still pending on this
     * request — as "superseded" — then remove its listeners. Called at the
     * start of every `preload()`/`display()` (so a new call supersedes the
     * previous one instead of leaving its promise pending forever) and after
     * the nominal DISMISSED / native-rejection paths resolve their own
     * promise (a no-op there since {@link pendingSettler} was already cleared).
     */
    private teardownSubscriptions(): void {
        this.settlePendingAsSuperseded();
        for (const subscription of this.subscriptions) {
            subscription.remove();
        }
        this.subscriptions = [];
    }

    /**
     * Settle the currently pending `preload()`/`display()` promise (if any)
     * as superseded, without invoking any of the request's callbacks —
     * only the promise settles. `preload()` rejects; `display()` resolves
     * with a synthetic {@link PLYPresentationOutcome} (it never rejects).
     */
    private settlePendingAsSuperseded(): void {
        const pending = this.pendingSettler;
        if (!pending) {
            return;
        }
        this.pendingSettler = null;
        if (pending.kind === 'preload') {
            pending.reject({
                message:
                    'Preload superseded by a newer preload()/display() call on the same request.',
            });
        } else {
            pending.resolve({
                presentation: this.livePresentation,
                purchaseResult: null,
                plan: null,
                closeReason: null,
                error: {
                    message:
                        'Display superseded by a newer display() call on the same request.',
                },
            });
        }
    }

    private toNativePayload(): Record<string, unknown> {
        return {
            placementId: this.config.placementId ?? null,
            // Map `screenId` → native `presentationId` for the bridges.
            presentationId: this.config.screenId ?? null,
            isDefault: this.config.isDefault ?? false,
            contentId: this.config.contentId ?? null,
            backgroundColor: this.config.backgroundColor ?? null,
            progressColor: this.config.progressColor ?? null,
            displayCloseButton: this.config.displayCloseButton ?? null,
            displayBackButton: this.config.displayBackButton ?? null,
        };
    }
}

/**
 * Module-scoped subscription backing the single global default-dismiss handler.
 * The native SDK keeps a single handler, so we mirror that by replacing any
 * previous subscription whenever a new handler is registered.
 */
let defaultDismissSubscription: EmitterSubscription | null = null;

/**
 * Register the global handler invoked when a dismissed presentation is **not**
 * handled locally. It receives two categories of dismissals (parity with the
 * Flutter/native SDKs):
 *
 * 1. Presentations the app did **not** instantiate itself — a campaign, a
 *    deeplink, or a Promoted In-App Purchase (delivered by native through a
 *    dedicated event).
 * 2. Presentations the app **did** display itself via `request.display()` but
 *    for which it registered **no** local `onDismissed` callback. In that case
 *    the outcome is still surfaced to the promise returned by `display()`, and
 *    additionally routed here. If a local `onDismissed` **is** set, it wins and
 *    this default handler is **not** called for that presentation.
 *
 * This is the v6 replacement for the removed
 * `setDefaultPresentationResultCallback` / `setDefaultPresentationResultHandler`
 * (it mirrors the native `Purchasely.setDefaultPresentationDismissHandler`).
 *
 * The handler receives the rich {@link PLYPresentationOutcome}; its
 * {@link PLYPresentationOutcome.presentation} field is populated whenever the
 * SDK knows which screen closed, so the app can tell which paywall dismissed.
 *
 * Like the native SDK, only one handler is active at a time — calling this
 * again replaces the previous one. Returns the underlying
 * {@link EmitterSubscription} so callers can `.remove()` it (e.g. on unmount);
 * {@link removeDefaultPresentationDismissHandler} does the same.
 *
 * @example
 * ```ts
 * Purchasely.setDefaultPresentationDismissHandler((outcome) => {
 *   console.log(
 *     outcome.presentation?.screenId,
 *     outcome.purchaseResult,
 *     outcome.closeReason
 *   )
 * })
 * ```
 */
export function setDefaultPresentationDismissHandler(
    handler: (outcome: PLYPresentationOutcome) => void
): EmitterSubscription {
    // Single global handler: drop the previous subscription before re-arming.
    if (defaultDismissSubscription) {
        defaultDismissSubscription.remove();
        defaultDismissSubscription = null;
    }

    // Keep a live reference so the per-request DISMISSED fallback (in
    // PLYPresentationRequest) can reach it when no local `onDismissed` is set.
    currentDefaultDismissHandler = handler;

    // Tell native to (re)register its global dismiss handler. Fire-and-forget:
    // outcomes arrive through DEFAULT_DISMISSED events, not this call's return.
    NativeModules.Purchasely.setDefaultPresentationDismissHandler();

    defaultDismissSubscription = presentationEventEmitter.addListener(
        PURCHASELY_PRESENTATION_EVENTS.DEFAULT_DISMISSED,
        (event: PLYPresentationLifecycleEvent) => {
            const presentation = normalizePresentation(event.presentation);
            handler(eventToOutcome(event, presentation));
        }
    );

    return defaultDismissSubscription;
}

/** Remove the global default-dismiss handler registered above, if any. */
export function removeDefaultPresentationDismissHandler(): void {
    if (defaultDismissSubscription) {
        defaultDismissSubscription.remove();
        defaultDismissSubscription = null;
    }
    // Drop the live reference so the per-request DISMISSED fallback stops
    // routing to it once the host removes its default handler.
    currentDefaultDismissHandler = null;
    // Tell native to actually stop invoking its stored handler — without this,
    // the native SDK keeps calling it and emitting DEFAULT_DISMISSED events
    // that no JS listener is left to filter out.
    NativeModules.Purchasely.removeDefaultPresentationDismissHandler();
}
