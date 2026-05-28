import { NativeModules } from 'react-native';

import { LogLevels, RunningMode } from '../enums';

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
    androidStores: AndroidStore[];
    storekitVersion: StorekitVersion;
}

/**
 * Cross-platform builder for `Purchasely.start()` (v6).
 *
 * Mirrors the Android/iOS contract:
 * - `allowDeeplink` / `allowCampaigns` are part of the chain (Android-style).
 *   On iOS the bridge expands them to the equivalent class funcs while the
 *   native chain catches up.
 * - `stores(...)` is Android-only.
 * - `storekitVersion(...)` is iOS-only.
 *
 * In v6 the default running mode is `'observer'` — the host app keeps full
 * control of the purchase flow unless it opts into `'full'`.
 */
export class PurchaselyBuilder {
    /**
     * Version string forwarded to the native layer (`sdkBridgeVersion`).
     * Populated by the package root before exposing the builder.
     *
     * @internal
     */
    static bridgeVersion = '6.0.0';

    private constructor(private readonly state: StartBuilderState) {}

    static apiKey(key: string): PurchaselyBuilder {
        return new PurchaselyBuilder({
            apiKey: key,
            runningMode: 'observer',
            logLevel: 'error',
            allowDeeplink: true,
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

        // Apply the v6 chain-only options through the bridge.
        if (NativeModules.Purchasely.v6ApplyStartOptions) {
            NativeModules.Purchasely.v6ApplyStartOptions({
                allowDeeplink: this.state.allowDeeplink,
                allowCampaigns: this.state.allowCampaigns,
            });
        } else {
            // Fallback for older native bridges still ignoring v6ApplyStartOptions.
            NativeModules.Purchasely.readyToOpenDeeplink(
                this.state.allowDeeplink
            );
        }

        return configured;
    }
}
