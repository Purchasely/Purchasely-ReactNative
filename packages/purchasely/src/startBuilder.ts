import { NativeModules } from 'react-native';

import { LogLevels, RunningMode } from './enums';

type LogLevelString = 'debug' | 'info' | 'warn' | 'error';
type RunningModeString = 'observer' | 'full';
type AndroidStore = 'google' | 'huawei' | 'amazon';
type StorekitVersion = 'storeKit1' | 'storeKit2';

const LOG_LEVEL_MAP: Record<LogLevelString, LogLevels> = {
    debug: LogLevels.DEBUG,
    info: LogLevels.INFO,
    warn: LogLevels.WARNING,
    error: LogLevels.ERROR,
};

const RUNNING_MODE_MAP: Record<RunningModeString, RunningMode> = {
    observer: RunningMode.OBSERVER,
    full: RunningMode.FULL,
};

interface StartBuilderState {
    apiKey: string;
    appUserId?: string | null;
    runningMode: RunningModeString;
    logLevel: LogLevelString;
    allowDeeplink?: boolean | null;
    allowCampaigns?: boolean | null;
    automaticDeeplinkHandling?: boolean | null;
    deeplink?: string | null;
    anonymousUserId?: string | null;
    anonymousUserIdOverride?: boolean | null;
    proxyApi?: string | null;
    appHandlesRedemptionAlert?: boolean | null;
    androidStores: AndroidStore[];
    storekitVersion: StorekitVersion;
}

/**
 * Cross-platform builder for `Purchasely.start()`.
 *
 * Mirrors the Android/iOS contract:
 * - `allowDeeplink` / `allowCampaigns` are optional chain modifiers.
 *   When omitted we keep each native SDK's default/backend-configured value.
 * - `stores(...)` is Android-only.
 * - `proxy(...)` is Android-only.
 * - `storekitVersion(...)` is iOS-only.
 *
 * The default running mode is `'observer'` — the host app keeps full
 * control of the purchase flow unless it opts into `'full'`.
 */
export class PurchaselyBuilder {
    /**
     * Version string forwarded to the native layer (`sdkBridgeVersion`).
     * Populated by the package root before exposing the builder.
     *
     * @internal
     */
    static bridgeVersion = '6.1.0';

    private constructor(private readonly state: StartBuilderState) {}

    static apiKey(key: string): PurchaselyBuilder {
        return new PurchaselyBuilder({
            apiKey: key,
            runningMode: 'observer',
            logLevel: 'error',
            androidStores: ['google'],
            storekitVersion: 'storeKit2',
        });
    }

    appUserId(id: string | null): this {
        this.state.appUserId = id;
        return this;
    }

    runningMode(mode: RunningModeString): this {
        this.state.runningMode = mode;
        return this;
    }

    logLevel(level: LogLevelString): this {
        this.state.logLevel = level;
        return this;
    }

    allowDeeplink(allow: boolean): this {
        this.state.allowDeeplink = allow;
        return this;
    }

    allowCampaigns(allow: boolean): this {
        this.state.allowCampaigns = allow;
        return this;
    }

    /**
     * Android-only. Toggle the SDK's automatic deeplink interception. When
     * omitted, the native SDK keeps its default. Ignored on iOS.
     */
    automaticDeeplinkHandling(enabled: boolean): this {
        this.state.automaticDeeplinkHandling = enabled;
        return this;
    }

    /**
     * Cold-start deeplink: pass a deeplink URL captured at launch (e.g. from
     * the Android intent / iOS scene connection options) so the SDK resolves it
     * automatically once started. No separate `Purchasely.handleDeeplink()`
     * call is needed — the deeplink is replayed after `start()` completes.
     *
     * Pass `null` (or omit the modifier) when the app was not launched from a
     * deeplink. Non-Purchasely URLs are ignored by the native SDK.
     */
    handleDeeplink(deeplink: string | null): this {
        this.state.deeplink = deeplink;
        return this;
    }

    /**
     * Set the anonymous user id that the SDK reports for this device.
     *
     * `id` must be a canonical UUID string, for example
     * `'3f2504e0-4f89-11d3-9a0c-0305e82c3301'`. JavaScript has no UUID type,
     * so the native bridge parses the string. The bridge logs an error and
     * skips the modifier when the string is not a canonical UUID. The SDK
     * still starts.
     *
     * The SDK stores the id in **uppercase**, on iOS and on Android.
     *
     * The SDK applies the id at `start()`, before it sends a network request
     * or an event. The SDK applies the id only when the device holds no
     * anonymous id yet, unless `override` is `true`.
     *
     * **`override: true` splits the user history.** The backend keeps every
     * event and every purchase under the previous id. Use `override: true`
     * only when the app owns the anonymous identity, for example after a
     * cross-device restore.
     *
     * @param id A canonical UUID string.
     * @param override `false` (the default) keeps an id that the SDK
     * established before. `true` replaces it.
     */
    anonymousUserId(id: string, override: boolean = false): this {
        this.state.anonymousUserId = id;
        this.state.anonymousUserIdOverride = override;
        return this;
    }

    /**
     * Android-only.
     *
     * Route Purchasely API traffic through a proxy instead of
     * `api.purchasely.io`, for a region where that host is unreachable. The
     * SDK overrides the API host only: the paywall host and the tracking
     * host always stay on production.
     *
     * `api` must be an `https` base URL. The native SDK refuses any other
     * value with an error log and keeps the production host, so the bridge
     * does not validate the value again.
     *
     * @param api The `https` base URL of the API proxy.
     */
    proxy(api: string): this {
        this.state.proxyApi = api;
        return this;
    }

    /**
     * Hand the Web2App redemption result screen to the app.
     *
     * This flag decides who shows the outcome of a redemption, and with it
     * when the SDK calls the listener that you add with
     * `Purchasely.addWebRedemptionListener`:
     *
     * - `false` (the default): the SDK shows its own popin and calls the
     *   listener after the user acknowledges the popin.
     * - `true`: the SDK shows nothing and calls the listener as soon as the
     *   redemption settles. The app must then show its own result screen.
     *
     * This is a start-time option because it changes what the native SDK
     * presents. Set it before `start()`.
     */
    appHandlesRedemptionAlert(handles: boolean): this {
        this.state.appHandlesRedemptionAlert = handles;
        return this;
    }

    /** Android-only. */
    stores(stores: AndroidStore[]): this {
        this.state.androidStores = stores;
        return this;
    }

    /** iOS-only. */
    storekitVersion(version: StorekitVersion): this {
        this.state.storekitVersion = version;
        return this;
    }

    /**
     * Finalize the builder and start the SDK.
     *
     * @param sdkVersion Optional override for the bridge version string. By
     * default the version is injected by the wrapper exposed via
     * `Purchasely.builder()`.
     */
    async start(sdkVersion?: string): Promise<boolean> {
        const bridgeVersion = sdkVersion ?? PurchaselyBuilder.bridgeVersion;
        const androidStoreNames = this.state.androidStores.map((s) => {
            switch (s) {
                case 'google':
                    return 'Google';
                case 'huawei':
                    return 'Huawei';
                case 'amazon':
                    return 'Amazon';
                default:
                    return s;
            }
        });

        // Chain-only options, applied by native on/before its own start() call
        // (built into the same builder chain that starts the SDK) so there is no
        // window where a campaign/deeplink can fire against the wrong default.
        // Omitted options are intentionally absent so native defaults match
        // Flutter v6.
        const startOptions: Record<string, boolean | string> = {};
        if (this.state.allowDeeplink !== undefined && this.state.allowDeeplink !== null) {
            startOptions.allowDeeplink = this.state.allowDeeplink;
        }
        if (this.state.allowCampaigns !== undefined && this.state.allowCampaigns !== null) {
            startOptions.allowCampaigns = this.state.allowCampaigns;
        }
        if (
            this.state.automaticDeeplinkHandling !== undefined &&
            this.state.automaticDeeplinkHandling !== null
        ) {
            startOptions.automaticDeeplinkHandling = this.state.automaticDeeplinkHandling;
        }
        // The bridge parses `anonymousUserId` into a native UUID. An invalid
        // string is rejected there, with a log, and start() still succeeds.
        if (this.state.anonymousUserId !== undefined && this.state.anonymousUserId !== null) {
            startOptions.anonymousUserId = this.state.anonymousUserId;
            startOptions.anonymousUserIdOverride = this.state.anonymousUserIdOverride ?? false;
        }
        if (this.state.proxyApi !== undefined && this.state.proxyApi !== null) {
            startOptions.proxy = this.state.proxyApi;
        }
        if (
            this.state.appHandlesRedemptionAlert !== undefined &&
            this.state.appHandlesRedemptionAlert !== null
        ) {
            startOptions.appHandlesRedemptionAlert = this.state.appHandlesRedemptionAlert;
        }

        const configured: boolean = await NativeModules.Purchasely.start(
            this.state.apiKey,
            androidStoreNames,
            this.state.storekitVersion === 'storeKit1',
            this.state.appUserId ?? null,
            LOG_LEVEL_MAP[this.state.logLevel],
            RUNNING_MODE_MAP[this.state.runningMode],
            bridgeVersion,
            startOptions
        );

        // Replay a cold-start deeplink now that the SDK is configured.
        if (this.state.deeplink) {
            await NativeModules.Purchasely.handleDeeplink(this.state.deeplink);
        }

        return configured;
    }
}
