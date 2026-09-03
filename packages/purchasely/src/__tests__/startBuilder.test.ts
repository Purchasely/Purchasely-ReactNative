/**
 * Unit tests for PurchaselyBuilder (packages/purchasely/src/startBuilder.ts).
 *
 * index.test.ts exercises the builder through `Purchasely.builder()` /
 * `Purchasely.apiKey()` for the common paths (default start + allowDeeplink/
 * allowCampaigns). This file drives `PurchaselyBuilder` directly to cover the
 * chain modifiers that were previously untested: `stores()`,
 * `storekitVersion()`, `runningMode()`, `logLevel()`, `appUserId()`, the
 * atomic `startOptions` map passed to native `start()`, the cold-start
 * `handleDeeplink()` replay, and the `sdkVersion` override.
 */

import { mockConstants } from '../__mocks__/testUtils'

// ES imports are hoisted above plain `const` statements even when written
// after them, so the mock native module must be self-contained inside the
// factory (matching the pattern used by presentation.integration.test.ts) —
// referencing an outer-scope object here would still be `undefined` when the
// factory actually runs.
jest.mock('react-native', () => ({
    NativeModules: {
        Purchasely: {
            getConstants: jest.fn(() => require('../__mocks__/testUtils').mockConstants),
            start: jest.fn().mockResolvedValue(true),
            handleDeeplink: jest.fn().mockResolvedValue(true),
        },
    },
}))

import { NativeModules } from 'react-native'
import { PurchaselyBuilder } from '../startBuilder'

const mockNative = NativeModules.Purchasely as any

describe('PurchaselyBuilder', () => {
    beforeEach(() => {
        jest.clearAllMocks()
        mockNative.start = jest.fn().mockResolvedValue(true)
        mockNative.handleDeeplink = jest.fn().mockResolvedValue(true)
        // Static field can leak mutations across tests — reset to the
        // package default before each test.
        PurchaselyBuilder.bridgeVersion = '6.1.0'
    })

    describe('apiKey() defaults', () => {
        it('starts with the documented v6 defaults (observer, error, google, storeKit2)', async () => {
            await PurchaselyBuilder.apiKey('api-key').start()

            expect(mockNative.start).toHaveBeenCalledWith(
                'api-key',
                ['Google'],
                false, // storeKit1 === false -> storeKit2 default
                null, // appUserId
                mockConstants.logLevelError,
                mockConstants.runningModeObserver,
                '6.1.0',
                {} // no chain-only options set -> empty startOptions map
            )
        })
    })

    describe('appUserId()', () => {
        it('forwards the app user id as the 4th positional argument', async () => {
            await PurchaselyBuilder.apiKey('api-key').appUserId('user-42').start()

            const args = mockNative.start.mock.calls[0]
            expect(args[3]).toBe('user-42')
        })

        it('defaults appUserId to null when not called', async () => {
            await PurchaselyBuilder.apiKey('api-key').start()
            expect(mockNative.start.mock.calls[0][3]).toBeNull()
        })
    })

    describe('runningMode()', () => {
        it('maps "full" to the native runningModeFull ordinal', async () => {
            await PurchaselyBuilder.apiKey('api-key').runningMode('full').start()
            expect(mockNative.start.mock.calls[0][5]).toBe(mockConstants.runningModeFull)
        })

        it('maps "observer" to the native runningModeObserver ordinal', async () => {
            await PurchaselyBuilder.apiKey('api-key').runningMode('observer').start()
            expect(mockNative.start.mock.calls[0][5]).toBe(mockConstants.runningModeObserver)
        })
    })

    describe('logLevel()', () => {
        it.each([
            ['debug', 'logLevelDebug'],
            ['info', 'logLevelInfo'],
            ['warn', 'logLevelWarn'],
            ['error', 'logLevelError'],
        ] as const)('maps "%s" to the native %s ordinal', async (level, constantKey) => {
            await PurchaselyBuilder.apiKey('api-key').logLevel(level).start()
            expect(mockNative.start.mock.calls[0][4]).toBe(
                (mockConstants as Record<string, number>)[constantKey]
            )
        })
    })

    describe('stores() — Android only', () => {
        it('maps store ids to the native display names, preserving order', async () => {
            await PurchaselyBuilder.apiKey('api-key')
                .stores(['huawei', 'amazon', 'google'])
                .start()

            expect(mockNative.start.mock.calls[0][1]).toEqual(['Huawei', 'Amazon', 'Google'])
        })

        it('defaults to ["Google"] when stores() is never called', async () => {
            await PurchaselyBuilder.apiKey('api-key').start()
            expect(mockNative.start.mock.calls[0][1]).toEqual(['Google'])
        })
    })

    describe('storekitVersion() — iOS only', () => {
        it('storeKit1 sets the 3rd positional argument to true', async () => {
            await PurchaselyBuilder.apiKey('api-key').storekitVersion('storeKit1').start()
            expect(mockNative.start.mock.calls[0][2]).toBe(true)
        })

        it('storeKit2 (default) sets the 3rd positional argument to false', async () => {
            await PurchaselyBuilder.apiKey('api-key').storekitVersion('storeKit2').start()
            expect(mockNative.start.mock.calls[0][2]).toBe(false)
        })
    })

    describe('allowDeeplink() / allowCampaigns() chain modifiers — atomic startOptions map', () => {
        it('passes only allowDeeplink in the startOptions map (8th arg) when only it is set', async () => {
            await PurchaselyBuilder.apiKey('api-key').allowDeeplink(true).start()
            expect(mockNative.start.mock.calls[0][7]).toEqual({ allowDeeplink: true })
        })

        it('passes only allowCampaigns in the startOptions map when only it is set', async () => {
            await PurchaselyBuilder.apiKey('api-key').allowCampaigns(false).start()
            expect(mockNative.start.mock.calls[0][7]).toEqual({ allowCampaigns: false })
        })

        it('passes both in the startOptions map when both are set', async () => {
            await PurchaselyBuilder.apiKey('api-key')
                .allowDeeplink(true)
                .allowCampaigns(true)
                .start()
            expect(mockNative.start.mock.calls[0][7]).toEqual({
                allowDeeplink: true,
                allowCampaigns: true,
            })
        })

        it('passes an empty startOptions map when neither modifier is set', async () => {
            await PurchaselyBuilder.apiKey('api-key').start()
            expect(mockNative.start.mock.calls[0][7]).toEqual({})
        })

        it('forwards automaticDeeplinkHandling (Android-only) through the startOptions map', async () => {
            await PurchaselyBuilder.apiKey('api-key').automaticDeeplinkHandling(false).start()
            expect(mockNative.start.mock.calls[0][7]).toEqual({
                automaticDeeplinkHandling: false,
            })
        })

        it('the startOptions map is passed as part of the single start() call — no separate native call follows', async () => {
            const callOrder: string[] = []
            mockNative.start = jest.fn().mockImplementation(async () => {
                callOrder.push('start')
                return true
            })

            await PurchaselyBuilder.apiKey('api-key').allowDeeplink(true).start()

            expect(callOrder).toEqual(['start'])
        })
    })

    describe('anonymousUserId() — 6.1.0', () => {
        it('forwards the id and the default override=false through startOptions', async () => {
            await PurchaselyBuilder.apiKey('api-key')
                .anonymousUserId('3f2504e0-4f89-11d3-9a0c-0305e82c3301')
                .start()

            expect(mockNative.start.mock.calls[0][7]).toEqual({
                anonymousUserId: '3f2504e0-4f89-11d3-9a0c-0305e82c3301',
                anonymousUserIdOverride: false,
            })
        })

        it('forwards override=true when asked', async () => {
            await PurchaselyBuilder.apiKey('api-key')
                .anonymousUserId('3f2504e0-4f89-11d3-9a0c-0305e82c3301', true)
                .start()

            expect(mockNative.start.mock.calls[0][7]).toEqual({
                anonymousUserId: '3f2504e0-4f89-11d3-9a0c-0305e82c3301',
                anonymousUserIdOverride: true,
            })
        })

        it('does not validate the string in JS — the bridge parses it and rejects a bad value', async () => {
            await expect(
                PurchaselyBuilder.apiKey('api-key').anonymousUserId('not-a-uuid').start()
            ).resolves.toBe(true)

            expect(mockNative.start.mock.calls[0][7]).toEqual({
                anonymousUserId: 'not-a-uuid',
                anonymousUserIdOverride: false,
            })
        })

        it('omits both keys when the modifier is never called', async () => {
            await PurchaselyBuilder.apiKey('api-key').start()
            expect(mockNative.start.mock.calls[0][7]).toEqual({})
        })
    })

    describe('proxy() — Android only, 6.1.0', () => {
        it('forwards the api url through startOptions', async () => {
            await PurchaselyBuilder.apiKey('api-key')
                .proxy('https://svc.purchasely.io')
                .start()

            expect(mockNative.start.mock.calls[0][7]).toEqual({
                proxy: 'https://svc.purchasely.io',
            })
        })

        it('does not validate the scheme in JS — the native SDK refuses a bad value', async () => {
            await PurchaselyBuilder.apiKey('api-key').proxy('http://insecure.example').start()
            expect(mockNative.start.mock.calls[0][7]).toEqual({
                proxy: 'http://insecure.example',
            })
        })
    })

    describe('appHandlesRedemptionAlert() — 6.1.0', () => {
        it('forwards true through startOptions', async () => {
            await PurchaselyBuilder.apiKey('api-key').appHandlesRedemptionAlert(true).start()
            expect(mockNative.start.mock.calls[0][7]).toEqual({
                appHandlesRedemptionAlert: true,
            })
        })

        it('forwards an explicit false through startOptions', async () => {
            await PurchaselyBuilder.apiKey('api-key').appHandlesRedemptionAlert(false).start()
            expect(mockNative.start.mock.calls[0][7]).toEqual({
                appHandlesRedemptionAlert: false,
            })
        })

        it('omits the key when the modifier is never called', async () => {
            await PurchaselyBuilder.apiKey('api-key').start()
            expect(mockNative.start.mock.calls[0][7]).toEqual({})
        })
    })

    describe('the 6.1.0 options travel in the same atomic startOptions map', () => {
        it('carries every modifier in one start() call', async () => {
            await PurchaselyBuilder.apiKey('api-key')
                .allowDeeplink(false)
                .anonymousUserId('3f2504e0-4f89-11d3-9a0c-0305e82c3301', true)
                .proxy('https://svc.purchasely.io')
                .appHandlesRedemptionAlert(true)
                .start()

            expect(mockNative.start).toHaveBeenCalledTimes(1)
            expect(mockNative.start.mock.calls[0][7]).toEqual({
                allowDeeplink: false,
                anonymousUserId: '3f2504e0-4f89-11d3-9a0c-0305e82c3301',
                anonymousUserIdOverride: true,
                proxy: 'https://svc.purchasely.io',
                appHandlesRedemptionAlert: true,
            })
        })
    })

    describe('handleDeeplink() — cold-start replay', () => {
        it('replays the deeplink through native.handleDeeplink after start() resolves', async () => {
            const callOrder: string[] = []
            mockNative.start = jest.fn().mockImplementation(async () => {
                callOrder.push('start')
                return true
            })
            mockNative.handleDeeplink = jest.fn().mockImplementation(async (url: string) => {
                callOrder.push(`handleDeeplink:${url}`)
                return true
            })

            await PurchaselyBuilder.apiKey('api-key')
                .handleDeeplink('purchasely://cold-start')
                .start()

            expect(mockNative.handleDeeplink).toHaveBeenCalledWith('purchasely://cold-start')
            expect(callOrder).toEqual(['start', 'handleDeeplink:purchasely://cold-start'])
        })

        it('does not call native.handleDeeplink when no cold-start deeplink was set', async () => {
            await PurchaselyBuilder.apiKey('api-key').start()
            expect(mockNative.handleDeeplink).not.toHaveBeenCalled()
        })

        it('does not call native.handleDeeplink when explicitly set to null', async () => {
            await PurchaselyBuilder.apiKey('api-key').handleDeeplink(null).start()
            expect(mockNative.handleDeeplink).not.toHaveBeenCalled()
        })
    })

    describe('start() return value + bridge version', () => {
        it('resolves with the native start() result', async () => {
            mockNative.start = jest.fn().mockResolvedValue(false)
            await expect(PurchaselyBuilder.apiKey('api-key').start()).resolves.toBe(false)
        })

        it('uses the static bridgeVersion by default', async () => {
            await PurchaselyBuilder.apiKey('api-key').start()
            expect(mockNative.start.mock.calls[0][6]).toBe('6.1.0')
        })

        it('overrides the bridge version with the sdkVersion argument when provided', async () => {
            await PurchaselyBuilder.apiKey('api-key').start('9.9.9-custom')
            expect(mockNative.start.mock.calls[0][6]).toBe('9.9.9-custom')
        })
    })
})
