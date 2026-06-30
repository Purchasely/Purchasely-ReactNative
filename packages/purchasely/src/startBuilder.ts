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
    allowDeeplink: boolean;
    allowCampaigns: boolean;
    deeplink?: string | null;
    androidStores: AndroidStore[];
    storekitVersion: StorekitVersion;
}

/**
 * Cross-platform builder for `Purchasely.start()`.
 *
 * Mirrors the Android/iOS contract:
 * - `allowDeeplink` / `allowCampaigns` are part of the chain (Android-style).
 *   On iOS the bridge expands them to the equivalent class funcs while the
 *   native chain catches up.
 * - `stores(...)` is Android-only.
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
    static bridgeVersion = '6.0.0-rc.2';

    private constructor(private readonly state: StartBuilderState) {}

    static apiKey(key: string): PurchaselyBuilder {
        return new PurchaselyBuilder({
            apiKey: key,
            runningMode: 'observer',
            logLevel: 'error',
            allowDeeplink: false,
            allowCampaigns: true,
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

        const configured: boolean = await NativeModules.Purchasely.start(
            this.state.apiKey,
            androidStoreNames,
            this.state.storekitVersion === 'storeKit1',
            this.state.appUserId ?? null,
            LOG_LEVEL_MAP[this.state.logLevel],
            RUNNING_MODE_MAP[this.state.runningMode],
            bridgeVersion
        );

        // Apply the chain-only options through the bridge.
        if (NativeModules.Purchasely.applyStartOptions) {
            NativeModules.Purchasely.applyStartOptions({
                allowDeeplink: this.state.allowDeeplink,
                allowCampaigns: this.state.allowCampaigns,
            });
        } else {
            // Fallback for older native bridges still ignoring applyStartOptions.
            NativeModules.Purchasely.readyToOpenDeeplink(
                this.state.allowDeeplink
            );
        }

        // Replay a cold-start deeplink now that the SDK is configured.
        if (this.state.deeplink) {
            await NativeModules.Purchasely.handleDeeplink(this.state.deeplink);
        }

        return configured;
    }
}
