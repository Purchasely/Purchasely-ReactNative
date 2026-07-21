/**
 * Unit tests for PurchaselyBuilder (packages/purchasely/src/startBuilder.ts).
 *
 * index.test.ts exercises the builder through `Purchasely.builder()` /
 * `Purchasely.apiKey()` for the common paths (default start + allowDeeplink/
 * allowCampaigns). This file drives `PurchaselyBuilder` directly to cover the
 * chain modifiers that were previously untested: `stores()`,
 * `storekitVersion()`, `runningMode()`, `logLevel()`, `appUserId()`, the
 * cold-start `handleDeeplink()` replay, the `applyStartOptions` /
 * `readyToOpenDeeplink` fallback branch, and the `sdkVersion` override.
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
            applyStartOptions: jest.fn(),
            readyToOpenDeeplink: jest.fn(),
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
        mockNative.applyStartOptions = jest.fn()
        mockNative.readyToOpenDeeplink = jest.fn()
        mockNative.handleDeeplink = jest.fn().mockResolvedValue(true)
        // Static field can leak mutations across tests — reset to the
        // package default before each test.
        PurchaselyBuilder.bridgeVersion = '6.0.0-rc.3'
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
                '6.0.0-rc.3'
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

    describe('allowDeeplink() / allowCampaigns() chain modifiers', () => {
        it('calls applyStartOptions with only allowDeeplink when only it is set', async () => {
            await PurchaselyBuilder.apiKey('api-key').allowDeeplink(true).start()
            expect(mockNative.applyStartOptions).toHaveBeenCalledWith({ allowDeeplink: true })
        })

        it('calls applyStartOptions with only allowCampaigns when only it is set', async () => {
            await PurchaselyBuilder.apiKey('api-key').allowCampaigns(false).start()
            expect(mockNative.applyStartOptions).toHaveBeenCalledWith({ allowCampaigns: false })
        })

        it('calls applyStartOptions with both when both are set', async () => {
            await PurchaselyBuilder.apiKey('api-key')
                .allowDeeplink(true)
                .allowCampaigns(true)
                .start()
            expect(mockNative.applyStartOptions).toHaveBeenCalledWith({
                allowDeeplink: true,
                allowCampaigns: true,
            })
        })

        it('does not call applyStartOptions when neither modifier is set', async () => {
            await PurchaselyBuilder.apiKey('api-key').start()
            expect(mockNative.applyStartOptions).not.toHaveBeenCalled()
        })

        it('falls back to readyToOpenDeeplink when the native bridge has no applyStartOptions', async () => {
            delete mockNative.applyStartOptions
            await PurchaselyBuilder.apiKey('api-key').allowDeeplink(true).start()
            expect(mockNative.readyToOpenDeeplink).toHaveBeenCalledWith(true)
        })

        it('does not call the readyToOpenDeeplink fallback for allowCampaigns-only (no allowDeeplink key)', async () => {
            delete mockNative.applyStartOptions
            await PurchaselyBuilder.apiKey('api-key').allowCampaigns(true).start()
            expect(mockNative.readyToOpenDeeplink).not.toHaveBeenCalled()
        })

        it('forwards automaticDeeplinkHandling (Android-only) through applyStartOptions', async () => {
            await PurchaselyBuilder.apiKey('api-key').automaticDeeplinkHandling(false).start()
            expect(mockNative.applyStartOptions).toHaveBeenCalledWith({
                automaticDeeplinkHandling: false,
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
            expect(mockNative.start.mock.calls[0][6]).toBe('6.0.0-rc.3')
        })

        it('overrides the bridge version with the sdkVersion argument when provided', async () => {
            await PurchaselyBuilder.apiKey('api-key').start('9.9.9-custom')
            expect(mockNative.start.mock.calls[0][6]).toBe('9.9.9-custom')
        })
    })
})
