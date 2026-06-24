import { NativeModules } from 'react-native';
import type { EmitterSubscription } from 'react-native';

import type {
    Presentation,
    PresentationError,
    PLYPresentationOutcome,
    Transition,
} from './presentationTypes';
import { purchaseResultFromOrdinal } from './presentationTypes';
import { PURCHASELY_PRESENTATION_EVENTS, presentationEventEmitter } from './events';
import type { PresentationLifecycleEvent } from './events';

/** Counter for generating bridge request ids. */
let nextRequestId = 0;
const generateRequestId = (): string => {
    nextRequestId += 1;
    return `ply_req_${Date.now()}_${nextRequestId}`;
};

/** Normalize a native presentation payload to the {@link Presentation} shape. */
function normalizePresentation(raw: any): Presentation | null {
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
        language: raw.language ?? null,
        type: raw.type ?? null,
        plans: raw.plans ?? null,
        metadata: raw.metadata ?? null,
        height: raw.height ?? null,
    };
}

/** Normalize a native error payload to the {@link PresentationError} shape. */
function normalizeError(raw: any): PresentationError | null {
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
    event: PresentationLifecycleEvent,
    presentation: Presentation | null
): PLYPresentationOutcome {
    const error = normalizeError(event.error);
    return {
        presentation,
        purchaseResult: purchaseResultFromOrdinal(event.purchaseResult),
        plan: event.plan ?? null,
        // Exclusion rule (cf. contract): error != null ⇒ closeReason == null.
        closeReason: error ? null : event.closeReason ?? null,
        error,
    };
}

/**
 * Holds the callbacks registered on a {@link PresentationBuilder}. They are
 * shared between the builder, the request and the live {@link Presentation}
 * so that callbacks reassigned after `preload()` take effect.
 */
interface PresentationCallbacks {
    onLoaded?: (
        presentation: Presentation,
        error?: PresentationError | null
    ) => void;
    onPresented?: (
        presentation?: Presentation | null,
        error?: PresentationError | null
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
 * const request = PresentationBuilder.placement('ONBOARDING')
 *   .onDismissed((outcome) => console.log(outcome))
 *   .build();
 *
 * const outcome = await request.display();
 * ```
 */
export class PresentationBuilder {
    /** @internal */
    private readonly config: BuilderConfig;

    private constructor(config: BuilderConfig) {
        this.config = config;
    }

    /** Build a request that targets a placement vendor id. */
    static placement(placementId: string): PresentationBuilder {
        return new PresentationBuilder({
            placementId,
            callbacks: {},
        });
    }

    /**
     * Build a request that targets a specific presentation by its screen id.
     * On iOS this maps to `PLYPresentationBuilder.from(presentationId:)`.
     */
    static screen(screenId: string): PresentationBuilder {
        return new PresentationBuilder({
            screenId,
            callbacks: {},
        });
    }

    /** Build a request that uses the SDK's default placement. */
    static default(): PresentationBuilder {
        return new PresentationBuilder({
            isDefault: true,
            callbacks: {},
        });
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
     * Android only — no-op on iOS until native exposes the property.
     */
    displayCloseButton(show: boolean): this {
        this.config.displayCloseButton = show;
        return this;
    }

    /**
     * Android only — no-op on iOS until native exposes the property.
     */
    displayBackButton(show: boolean): this {
        this.config.displayBackButton = show;
        return this;
    }

    onLoaded(
        handler: (
            presentation: Presentation,
            error?: PresentationError | null
        ) => void
    ): this {
        this.config.callbacks.onLoaded = handler;
        return this;
    }

    onPresented(
        handler: (
            presentation?: Presentation | null,
            error?: PresentationError | null
        ) => void
    ): this {
        this.config.callbacks.onPresented = handler;
        return this;
    }

    onCloseRequested(handler: () => void): this {
        this.config.callbacks.onCloseRequested = handler;
        return this;
    }

    onDismissed(handler: (outcome: PLYPresentationOutcome) => void): this {
        this.config.callbacks.onDismissed = handler;
        return this;
    }

    /** Convert the builder into a runnable {@link PresentationRequest}. */
    build(): PresentationRequest {
        return new PresentationRequest(this.config);
    }
}

/**
 * Encapsulates a presentation request: it can be preloaded (without UI),
 * or displayed (which resolves at dismiss).
 */
export class PresentationRequest {
    /** @internal */
    private readonly config: BuilderConfig;
    /** @internal */
    private requestId: string | null = null;
    /** @internal */
    private subscriptions: EmitterSubscription[] = [];
    /** @internal */
    private livePresentation: Presentation | null = null;

    constructor(config: BuilderConfig) {
        this.config = config;
    }

    /**
     * Preload the presentation. Resolves once the SDK reports the screen
     * is loaded (`onLoaded`). Rejects if the SDK fails before load.
     */
    preload(): Promise<Presentation> {
        const requestId = this.ensureRequestId();
        return new Promise<Presentation>((resolve, reject) => {
            const loadedSubscription =
                presentationEventEmitter.addListener(
                    PURCHASELY_PRESENTATION_EVENTS.LOADED,
                    (event: PresentationLifecycleEvent) => {
                        if (event.requestId !== requestId) {
                            return;
                        }
                        loadedSubscription.remove();
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
                        resolve(presentation);
                    }
                );
            this.subscriptions.push(loadedSubscription);

            NativeModules.Purchasely.preloadPresentation(
                requestId,
                this.toNativePayload()
            ).catch((nativeError: any) => {
                loadedSubscription.remove();
                reject(normalizeError(nativeError));
            });
        });
    }

    /**
     * Display the presentation. Resolves at DISMISS with a
     * {@link PLYPresentationOutcome} (cf. contract P0.3). Subscribers can attach
     * their own `onPresented` / `onCloseRequested` callbacks via the builder.
     */
    display(transition?: Transition | null): Promise<PLYPresentationOutcome> {
        const requestId = this.ensureRequestId();

        // Allow multiple `display()` on the same request — clean up first.
        this.teardownSubscriptions();

        return new Promise<PLYPresentationOutcome>((resolve) => {
            this.bindLifecycleEvents(requestId, resolve);

            NativeModules.Purchasely.displayPresentation(
                requestId,
                this.toNativePayload(),
                transition ?? null
            ).catch((nativeError: any) => {
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
                if (this.config.callbacks.onDismissed) {
                    this.config.callbacks.onDismissed(outcome);
                }
                resolve(outcome);
                this.teardownSubscriptions();
            });
        });
    }

    /**
     * Replace the dismissed-callback after `preload()` / `display()`. Useful
     * for hot-swapping callbacks on a cached {@link Presentation}.
     */
    onDismissed(
        handler: (outcome: PLYPresentationOutcome) => void
    ): this {
        this.config.callbacks.onDismissed = handler;
        return this;
    }

    onPresented(
        handler: (
            presentation?: Presentation | null,
            error?: PresentationError | null
        ) => void
    ): this {
        this.config.callbacks.onPresented = handler;
        return this;
    }

    onCloseRequested(handler: () => void): this {
        this.config.callbacks.onCloseRequested = handler;
        return this;
    }

    /**
     * Programmatically close the presentation if it is currently visible.
     *
     * @remarks
     * The native SDK does not yet expose a per-request close, so this currently
     * dismisses **all** displayed presentations, not only this request. If your
     * app stacks presentations (e.g. a product page inside an onboarding flow),
     * calling `close()` on one will also dismiss the others.
     */
    close(): void {
        if (!this.requestId) {
            return;
        }
        NativeModules.Purchasely.closePresentation(this.requestId);
    }

    /** Navigate back inside a multi-step (Flow) presentation. */
    back(): void {
        if (!this.requestId) {
            return;
        }
        NativeModules.Purchasely.goBackToPreviousScreen(this.requestId);
    }

    private ensureRequestId(): string {
        if (!this.requestId) {
            this.requestId = generateRequestId();
        }
        return this.requestId;
    }

    private bindLifecycleEvents(
        requestId: string,
        resolve: (outcome: PLYPresentationOutcome) => void
    ): void {
        const onPresented = presentationEventEmitter.addListener(
            PURCHASELY_PRESENTATION_EVENTS.PRESENTED,
            (event: PresentationLifecycleEvent) => {
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
            (event: PresentationLifecycleEvent) => {
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
            (event: PresentationLifecycleEvent) => {
                if (event.requestId !== requestId) {
                    return;
                }
                const presentation =
                    normalizePresentation(event.presentation) ??
                    this.livePresentation;
                const outcome = eventToOutcome(event, presentation);
                if (this.config.callbacks.onDismissed) {
                    this.config.callbacks.onDismissed(outcome);
                }
                resolve(outcome);
                this.teardownSubscriptions();
            }
        );

        this.subscriptions.push(onPresented, onCloseRequested, onDismissed);
    }

    private teardownSubscriptions(): void {
        for (const subscription of this.subscriptions) {
            subscription.remove();
        }
        this.subscriptions = [];
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
 * Register the global handler invoked when a presentation the app did **not**
 * instantiate itself — a campaign, a deeplink, or a Promoted In-App Purchase —
 * is dismissed. This is the v6 replacement for the removed
 * `setDefaultPresentationResultCallback` / `setDefaultPresentationResultHandler`
 * (it mirrors the native `Purchasely.setDefaultPresentationDismissHandler`).
 *
 * The handler receives the rich {@link PLYPresentationOutcome}; its
 * {@link PLYPresentationOutcome.presentation} field is always populated for this
 * handler, so the app can tell which campaign/deeplink screen closed.
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

    // Tell native to (re)register its global dismiss handler. Fire-and-forget:
    // outcomes arrive through DEFAULT_DISMISSED events, not this call's return.
    NativeModules.Purchasely.setDefaultPresentationDismissHandler();

    defaultDismissSubscription = presentationEventEmitter.addListener(
        PURCHASELY_PRESENTATION_EVENTS.DEFAULT_DISMISSED,
        (event: PresentationLifecycleEvent) => {
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
}
