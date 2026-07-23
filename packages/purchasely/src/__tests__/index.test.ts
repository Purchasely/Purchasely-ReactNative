/**
 * Unit tests for Purchasely React Native SDK main module
 */

import {
    mockConstants,
    createMockPurchaselyModule,
    mockEventEmitter,
} from '../__mocks__/testUtils'

// Create mock functions for all native methods
// mockPurchaselyModule is created but not used directly - it sets up the mocks
createMockPurchaselyModule()

// Mock react-native before importing Purchasely
jest.mock('react-native', () => ({
    NativeModules: {
        Purchasely: {
            getConstants: jest.fn(() => mockConstants),
            start: jest.fn().mockResolvedValue(true),
            allowDeeplink: jest.fn(),
            allowCampaigns: jest.fn(),
            userLogin: jest.fn().mockResolvedValue(true),
            userLogout: jest.fn(),
            isAnonymous: jest.fn().mockResolvedValue(false),
            getAnonymousUserId: jest.fn().mockResolvedValue('anonymous-user-id'),
            setLogLevel: jest.fn(),
            readyToOpenDeeplink: jest.fn(),
            applyStartOptions: jest.fn(),
            setAttribute: jest.fn(),
            setLanguage: jest.fn(),
            synchronize: jest.fn(),
            closePresentation: jest.fn(),
            purchaseWithPlanVendorId: jest.fn().mockResolvedValue({
                vendorId: 'plan-id',
                productId: 'product-id',
                name: 'Test Plan',
            }),
            signPromotionalOffer: jest.fn().mockResolvedValue({
                planVendorId: 'plan-id',
                identifier: 'offer-id',
                signature: 'signature',
                nonce: 'nonce',
                keyIdentifier: 'key-id',
                timestamp: Date.now(),
            }),
            allProducts: jest.fn().mockResolvedValue([]),
            productWithIdentifier: jest.fn().mockResolvedValue({
                name: 'Test Product',
                vendorId: 'product-id',
                plans: [],
            }),
            planWithIdentifier: jest.fn().mockResolvedValue({
                vendorId: 'plan-id',
                productId: 'product-id',
                name: 'Test Plan',
            }),
            restoreAllProducts: jest.fn().mockResolvedValue(true),
            silentRestoreAllProducts: jest.fn().mockResolvedValue(true),
            userSubscriptions: jest.fn().mockResolvedValue([]),
            userSubscriptionsHistory: jest.fn().mockResolvedValue([]),
            handleDeeplink: jest.fn().mockResolvedValue(false),
            isEligibleForIntroOffer: jest.fn().mockResolvedValue(true),
            setUserAttributeWithString: jest.fn(),
            setUserAttributeWithNumber: jest.fn(),
            setUserAttributeWithBoolean: jest.fn(),
            setUserAttributeWithDate: jest.fn(),
            setUserAttributeWithStringArray: jest.fn(),
            setUserAttributeWithNumberArray: jest.fn(),
            setUserAttributeWithBooleanArray: jest.fn(),
            incrementUserAttribute: jest.fn(),
            decrementUserAttribute: jest.fn(),
            userAttributes: jest.fn().mockResolvedValue({}),
            userAttribute: jest.fn().mockResolvedValue(null),
            clearUserAttribute: jest.fn(),
            clearUserAttributes: jest.fn(),
            clientPresentationDisplayed: jest.fn(),
            clientPresentationClosed: jest.fn(),
            setCustomScreenProvider: jest.fn(),
            removeCustomScreenProvider: jest.fn(),
            executeConnection: jest.fn(),
            customScreenBack: jest.fn(),
            customScreenClose: jest.fn(),
            clearBuiltInAttributes: jest.fn(),
            getBuiltInAttributes: jest.fn().mockResolvedValue({ appsflyer_id: 'af-123' }),
            getBuiltInAttribute: jest.fn().mockResolvedValue('af-123'),
            setDefaultPresentationDismissHandler: jest.fn(),
            removeDefaultPresentationDismissHandler: jest.fn(),
            userDidConsumeSubscriptionContent: jest.fn(),
            setThemeMode: jest.fn(),
            setDynamicOffering: jest.fn().mockResolvedValue(true),
            getDynamicOfferings: jest.fn().mockResolvedValue([]),
            removeDynamicOffering: jest.fn(),
            clearDynamicOfferings: jest.fn(),
            revokeDataProcessingConsent: jest.fn(),
            setDebugMode: jest.fn(),
            closeAllScreens: jest.fn(),
            addListener: jest.fn(),
            removeListeners: jest.fn(),
        },
        PurchaselyView: {
            onPresentationClosed: jest.fn().mockResolvedValue({ result: 0, plan: null }),
        },
    },
    NativeEventEmitter: jest.fn(() => mockEventEmitter),
    Platform: {
        OS: 'ios',
        select: jest.fn((obj: any) => obj.ios),
    },
    requireNativeComponent: jest.fn(() => 'PurchaselyView'),
    findNodeHandle: jest.fn(() => 1),
    UIManager: {
        dispatchViewManagerCommand: jest.fn(),
        PurchaselyView: {
            Commands: {
                create: 1,
            },
        },
    },
}))

// Now import Purchasely after mocking
import Purchasely, { PLYPresentationBuilder } from '../index'
import * as PurchaselyIndexModule from '../index'
import { Attributes, LogLevels, PLYThemeMode, PLYDataProcessingLegalBasis, PLYDataProcessingPurpose } from '../enums'
import { NativeModules } from 'react-native'

// Get reference to the mocked module
const mockedPurchasely = NativeModules.Purchasely

describe('Purchasely SDK', () => {
    beforeEach(() => {
        jest.clearAllMocks()
    })

    describe('Initialization', () => {
        // [PAR-12 / REC-17] getConstants() used to leak the raw native
        // constants blob (64 numeric fields, including v5 residue) as public
        // API. It is now internal-only — every enum in enums.ts still reads
        // from NativeModules.Purchasely.getConstants() directly at module
        // load, so nothing else changes; only this public re-export is gone.
        it('should no longer expose getConstants publicly', () => {
            expect((Purchasely as Record<string, unknown>).getConstants).toBeUndefined()
        })

        it('should start through the v6 builder without forcing optional start options', async () => {
            await Purchasely.builder('api-key').start()

            expect(mockedPurchasely.start).toHaveBeenCalledWith(
                'api-key',
                ['Google'],
                false,
                null,
                mockConstants.logLevelError,
                mockConstants.runningModeObserver,
                '6.0.0-rc.3'
            )
            expect(mockedPurchasely.applyStartOptions).not.toHaveBeenCalled()
        })

        it('should expose apiKey as the Flutter-compatible builder alias', async () => {
            await Purchasely.apiKey('api-key').allowDeeplink(true).allowCampaigns(false).start()

            expect(mockedPurchasely.start).toHaveBeenCalled()
            expect(mockedPurchasely.applyStartOptions).toHaveBeenCalledWith({
                allowDeeplink: true,
                allowCampaigns: false,
            })
        })

        it('should toggle deeplinks and campaigns at runtime', () => {
            Purchasely.allowDeeplink(true)
            Purchasely.allowCampaigns(false)

            expect(mockedPurchasely.allowDeeplink).toHaveBeenCalledWith(true)
            expect(mockedPurchasely.allowCampaigns).toHaveBeenCalledWith(false)
        })

        it('should expose Purchasely.presentation as the PLYPresentationBuilder entry point', () => {
            expect(Purchasely.presentation).toBe(PLYPresentationBuilder)
        })

        it('should not expose removed v5/top-level presentation APIs', () => {
            expect((Purchasely as any).close).toBeUndefined()
            expect((Purchasely as any).displaySubscriptionCancellationInstruction).toBeUndefined()
        })

        it('should not expose ANY of the v5 paywall surface removed by MIGRATION-v6.md', () => {
            // Full removed-methods table (MIGRATION-v6.md "Removed v5 paywall API →
            // v6 replacement"), beyond the two spot-checked above. Each of these
            // must stay absent from the exported Purchasely object — re-adding
            // one silently would resurrect a v5 API the migration guide promises
            // is gone.
            const removedV5TopLevelMethods = [
                'start', // object-style Purchasely.start({...}) — only PurchaselyBuilder#start exists now
                'startWithAPIKey',
                'fetchPresentation',
                'presentPresentationForPlacement',
                'presentPresentationWithIdentifier',
                'presentPresentation',
                'presentProductWithIdentifier',
                'presentPlanWithIdentifier',
                'showPresentation',
                'hidePresentation',
                'closePresentation', // top-level; request.close() replaces it
                'setPaywallActionInterceptorCallback',
                'onProcessAction',
                'setDefaultPresentationResultCallback',
                'setDefaultPresentationResultHandler',
                'readyToOpenDeeplink', // top-level; only reachable via builder.allowDeeplink()/start() internals
                'presentSubscriptions',
            ]

            removedV5TopLevelMethods.forEach((method) => {
                expect((Purchasely as Record<string, unknown>)[method]).toBeUndefined()
            })
        })

        // [PAR-14 / REC-17] purchaseResultFromOrdinal is an @internal helper
        // (presentationTypes.ts) used by presentation.ts; index.ts used to
        // re-export it publicly via `export * from './presentationTypes'`.
        // The barrel now uses `export type *`, which drops runtime value
        // exports — only the types from that module stay public.
        it('should not re-export the internal purchaseResultFromOrdinal helper from the package barrel', () => {
            expect((PurchaselyIndexModule as Record<string, unknown>).purchaseResultFromOrdinal).toBeUndefined()
        })

        it('should keep the client (BYOS) presentation API', () => {
            const presentation = {
                screenId: 'SCREEN_ID',
                placementId: 'PLACEMENT_ID',
            } as any

            Purchasely.clientPresentationDisplayed(presentation)
            Purchasely.clientPresentationClosed(presentation)

            expect(mockedPurchasely.clientPresentationDisplayed).toHaveBeenCalledWith({
                screenId: 'SCREEN_ID',
                placementId: 'PLACEMENT_ID',
            })
            expect(mockedPurchasely.clientPresentationClosed).toHaveBeenCalledWith({
                screenId: 'SCREEN_ID',
                placementId: 'PLACEMENT_ID',
            })
        })

        it('registers a Custom Screen component and drives its native presentation', async () => {
            const presentation = {
                screenId: 'CUSTOM_STEP',
                customScreenId: 'ply_cs_123',
            } as any

            await Purchasely.setCustomScreenProvider({
                componentName: 'PurchaselyCustomScreen',
            })
            Purchasely.executeConnection(presentation)
            Purchasely.executeConnection(presentation, 'continue')
            Purchasely.customScreenBack(presentation)
            Purchasely.customScreenClose(presentation)
            Purchasely.removeCustomScreenProvider()

            expect(mockedPurchasely.setCustomScreenProvider).toHaveBeenCalledWith(
                'PurchaselyCustomScreen'
            )
            expect(mockedPurchasely.executeConnection).toHaveBeenNthCalledWith(
                1,
                'ply_cs_123',
                null
            )
            expect(mockedPurchasely.executeConnection).toHaveBeenNthCalledWith(
                2,
                'ply_cs_123',
                'continue'
            )
            expect(mockedPurchasely.customScreenBack).toHaveBeenCalledWith(
                'ply_cs_123'
            )
            expect(mockedPurchasely.customScreenClose).toHaveBeenCalledWith(
                'ply_cs_123'
            )
            expect(mockedPurchasely.removeCustomScreenProvider).toHaveBeenCalled()
        })
    })

    describe('User Management', () => {
        it('should call userLogin with userId', async () => {
            const result = await Purchasely.userLogin('user-123')

            expect(result).toBe(true)
            expect(mockedPurchasely.userLogin).toHaveBeenCalledWith('user-123')
        })

        it('should call userLogout with clearUserAttributes defaulting to true', () => {
            Purchasely.userLogout()
            expect(mockedPurchasely.userLogout).toHaveBeenCalledWith(true)
        })

        // [PAR-30] Both native SDKs support choosing whether to clear locally
        // stored user attributes on logout; the bridge previously hardcoded
        // this to true (iOS) / omitted it entirely (Android), with no way for
        // the app to opt out.
        it('should forward an explicit clearUserAttributes value', () => {
            Purchasely.userLogout(false)
            expect(mockedPurchasely.userLogout).toHaveBeenCalledWith(false)
        })

        it('should check if user is anonymous', async () => {
            const result = await Purchasely.isAnonymous()

            expect(result).toBe(false)
            expect(mockedPurchasely.isAnonymous).toHaveBeenCalled()
        })

        it('should get anonymous user id', async () => {
            const result = await Purchasely.getAnonymousUserId()

            expect(result).toBe('anonymous-user-id')
            expect(mockedPurchasely.getAnonymousUserId).toHaveBeenCalled()
        })
    })

    describe('User Attributes', () => {
        it('should set string attribute', () => {
            Purchasely.setUserAttributeWithString('name', 'John')
            expect(mockedPurchasely.setUserAttributeWithString).toHaveBeenCalledWith(
                'name',
                'John',
                undefined
            )
        })

        it('should set string attribute with legal basis', () => {
            Purchasely.setUserAttributeWithString('name', 'John', PLYDataProcessingLegalBasis.ESSENTIAL)
            expect(mockedPurchasely.setUserAttributeWithString).toHaveBeenCalledWith(
                'name',
                'John',
                PLYDataProcessingLegalBasis.ESSENTIAL
            )
        })

        it('should set number attribute', () => {
            Purchasely.setUserAttributeWithNumber('age', 25)
            expect(mockedPurchasely.setUserAttributeWithNumber).toHaveBeenCalledWith(
                'age',
                25,
                undefined
            )
        })

        it('should expose int/double aliases for Flutter parity', () => {
            Purchasely.setUserAttributeWithInt('age', 25)
            Purchasely.setUserAttributeWithDouble('weight', 78.2)
            Purchasely.setUserAttributeWithIntArray('scores', [1, 2])
            Purchasely.setUserAttributeWithDoubleArray('weights', [1.5, 2.5])

            expect(mockedPurchasely.setUserAttributeWithNumber).toHaveBeenCalledWith(
                'age',
                25,
                undefined
            )
            expect(mockedPurchasely.setUserAttributeWithNumber).toHaveBeenCalledWith(
                'weight',
                78.2,
                undefined
            )
            expect(mockedPurchasely.setUserAttributeWithNumberArray).toHaveBeenCalledWith(
                'scores',
                [1, 2],
                undefined
            )
            expect(mockedPurchasely.setUserAttributeWithNumberArray).toHaveBeenCalledWith(
                'weights',
                [1.5, 2.5],
                undefined
            )
        })

        it('should set boolean attribute', () => {
            Purchasely.setUserAttributeWithBoolean('premium', true)
            expect(mockedPurchasely.setUserAttributeWithBoolean).toHaveBeenCalledWith(
                'premium',
                true,
                undefined
            )
        })

        it('should set date attribute with ISO string conversion', () => {
            const date = new Date('2024-01-15T12:00:00.000Z')
            Purchasely.setUserAttributeWithDate('birthdate', date)

            expect(mockedPurchasely.setUserAttributeWithDate).toHaveBeenCalledWith(
                'birthdate',
                '2024-01-15T12:00:00.000Z',
                undefined
            )
        })

        it('should set string array attribute', () => {
            Purchasely.setUserAttributeWithStringArray('tags', ['vip', 'active'])
            expect(mockedPurchasely.setUserAttributeWithStringArray).toHaveBeenCalledWith(
                'tags',
                ['vip', 'active'],
                undefined
            )
        })

        it('should set number array attribute', () => {
            Purchasely.setUserAttributeWithNumberArray('scores', [100, 200, 300])
            expect(mockedPurchasely.setUserAttributeWithNumberArray).toHaveBeenCalledWith(
                'scores',
                [100, 200, 300],
                undefined
            )
        })

        it('should set boolean array attribute', () => {
            Purchasely.setUserAttributeWithBooleanArray('flags', [true, false, true])
            expect(mockedPurchasely.setUserAttributeWithBooleanArray).toHaveBeenCalledWith(
                'flags',
                [true, false, true],
                undefined
            )
        })

        it('should increment user attribute with default value', () => {
            Purchasely.incrementUserAttribute({ key: 'counter' })
            expect(mockedPurchasely.incrementUserAttribute).toHaveBeenCalledWith(
                'counter',
                1,
                undefined
            )
        })

        it('should increment user attribute with custom value', () => {
            Purchasely.incrementUserAttribute({ key: 'counter', value: 5 })
            expect(mockedPurchasely.incrementUserAttribute).toHaveBeenCalledWith(
                'counter',
                5,
                undefined
            )
        })

        it('should decrement user attribute with default value', () => {
            Purchasely.decrementUserAttribute({ key: 'counter' })
            expect(mockedPurchasely.decrementUserAttribute).toHaveBeenCalledWith(
                'counter',
                1,
                undefined
            )
        })

        it('should decrement user attribute with custom value and legal basis', () => {
            Purchasely.decrementUserAttribute({
                key: 'counter',
                value: 3,
                legalBasis: PLYDataProcessingLegalBasis.OPTIONAL
            })
            expect(mockedPurchasely.decrementUserAttribute).toHaveBeenCalledWith(
                'counter',
                3,
                PLYDataProcessingLegalBasis.OPTIONAL
            )
        })

        it('should get user attributes', async () => {
            await Purchasely.userAttributes()
            expect(mockedPurchasely.userAttributes).toHaveBeenCalled()
        })

        it('should get specific user attribute', async () => {
            await Purchasely.userAttribute('name')
            expect(mockedPurchasely.userAttribute).toHaveBeenCalledWith('name')
        })

        it('should clear user attribute', () => {
            Purchasely.clearUserAttribute('name')
            expect(mockedPurchasely.clearUserAttribute).toHaveBeenCalledWith('name')
        })

        it('should clear all user attributes', () => {
            Purchasely.clearUserAttributes()
            expect(mockedPurchasely.clearUserAttributes).toHaveBeenCalled()
        })

        it('should clear built-in attributes', () => {
            Purchasely.clearBuiltInAttributes()
            expect(mockedPurchasely.clearBuiltInAttributes).toHaveBeenCalled()
        })

        // [PAR-07] getBuiltInAttribute(s) (read) — only clearBuiltInAttributes
        // was bridged before; the read side was missing on both natives.
        it('should read every built-in attribute', async () => {
            const attributes = await Purchasely.getBuiltInAttributes()

            expect(attributes).toEqual({ appsflyer_id: 'af-123' })
            expect(mockedPurchasely.getBuiltInAttributes).toHaveBeenCalled()
        })

        it('should read a single built-in attribute by key', async () => {
            const value = await Purchasely.getBuiltInAttribute('appsflyer_id')

            expect(value).toBe('af-123')
            expect(mockedPurchasely.getBuiltInAttribute).toHaveBeenCalledWith('appsflyer_id')
        })
    })

    describe('Third-party Attribution (setAttribute)', () => {
        it('should set a built-in third-party-integration attribute', () => {
            Purchasely.setAttribute(Attributes.FIREBASE_APP_INSTANCE_ID, 'instance-id-123')
            expect(mockedPurchasely.setAttribute).toHaveBeenCalledWith(
                Attributes.FIREBASE_APP_INSTANCE_ID,
                'instance-id-123'
            )
        })

        it('should forward the raw attribute ordinal for every known Attributes member', () => {
            Purchasely.setAttribute(Attributes.APPSFLYER_ID, 'appsflyer-id')
            Purchasely.setAttribute(Attributes.AMPLITUDE_DEVICE_ID, 'device-id')

            expect(mockedPurchasely.setAttribute).toHaveBeenNthCalledWith(
                1,
                Attributes.APPSFLYER_ID,
                'appsflyer-id'
            )
            expect(mockedPurchasely.setAttribute).toHaveBeenNthCalledWith(
                2,
                Attributes.AMPLITUDE_DEVICE_ID,
                'device-id'
            )
        })
    })

    describe('Products and Plans', () => {
        it('should get all products', async () => {
            await Purchasely.allProducts()
            expect(mockedPurchasely.allProducts).toHaveBeenCalled()
        })

        it('should get product with identifier', async () => {
            const result = await Purchasely.productWithIdentifier('product-123')

            expect(result.vendorId).toBe('product-id')
            expect(mockedPurchasely.productWithIdentifier).toHaveBeenCalledWith('product-123')
        })

        it('should get plan with identifier', async () => {
            const result = await Purchasely.planWithIdentifier('plan-123')

            expect(result.vendorId).toBe('plan-id')
            expect(mockedPurchasely.planWithIdentifier).toHaveBeenCalledWith('plan-123')
        })
    })

    describe('Purchases', () => {
        it('should purchase with plan vendor id', async () => {
            const result = await Purchasely.purchaseWithPlanVendorId({
                planVendorId: 'monthly-plan'
            })

            expect(result.vendorId).toBe('plan-id')
            expect(mockedPurchasely.purchaseWithPlanVendorId).toHaveBeenCalledWith(
                'monthly-plan',
                null,
                null
            )
        })

        it('should purchase with offer id', async () => {
            await Purchasely.purchaseWithPlanVendorId({
                planVendorId: 'monthly-plan',
                offerId: 'offer-123'
            })

            expect(mockedPurchasely.purchaseWithPlanVendorId).toHaveBeenCalledWith(
                'monthly-plan',
                'offer-123',
                null
            )
        })

        it('should restore all products', async () => {
            const result = await Purchasely.restoreAllProducts()

            expect(result).toBe(true)
            expect(mockedPurchasely.restoreAllProducts).toHaveBeenCalled()
        })

        it('should silent restore all products', async () => {
            const result = await Purchasely.silentRestoreAllProducts()

            expect(result).toBe(true)
            expect(mockedPurchasely.silentRestoreAllProducts).toHaveBeenCalled()
        })

        it('should sign promotional offer', async () => {
            const result = await Purchasely.signPromotionalOffer({
                storeProductId: 'product-123',
                storeOfferId: 'offer-123'
            })

            expect(result).not.toBeNull()
            expect(result?.planVendorId).toBe('plan-id')
            expect(mockedPurchasely.signPromotionalOffer).toHaveBeenCalledWith(
                'product-123',
                'offer-123'
            )
        })

        it('should check intro offer eligibility', async () => {
            const result = await Purchasely.isEligibleForIntroOffer('plan-123')

            expect(result).toBe(true)
            expect(mockedPurchasely.isEligibleForIntroOffer).toHaveBeenCalledWith('plan-123')
        })

        // RN-W-01 (fixed): the Android native bridge for signPromotionalOffer
        // used to be a permanent stub — `promise.reject("Not supported on
        // Android")` on every call, with no Platform.OS guard anywhere in
        // this JS wrapper, contradicting MIGRATION-v6.md's claim that the
        // method is "unchanged... in behaviour" on both platforms. Per
        // product decision, Android's native bridge now resolves as a no-op
        // success instead (there is no StoreKit-equivalent primitive on
        // Android). The explicit null result prevents callers from treating an
        // empty object as an iOS promotional-offer signature.
        it('resolves null when the Android native bridge no-ops (no StoreKit equivalent)', async () => {
            mockedPurchasely.signPromotionalOffer.mockResolvedValueOnce(null)

            await expect(
                Purchasely.signPromotionalOffer({
                    storeProductId: 'product-123',
                    storeOfferId: 'offer-123',
                })
            ).resolves.toBeNull()
        })
    })

    describe('Subscriptions', () => {
        it('should get user subscriptions', async () => {
            await Purchasely.userSubscriptions()
            expect(mockedPurchasely.userSubscriptions).toHaveBeenCalledWith(false)
        })

        it('should get user subscriptions with cache invalidation', async () => {
            await Purchasely.userSubscriptions({ invalidateCache: true })
            expect(mockedPurchasely.userSubscriptions).toHaveBeenCalledWith(true)
        })

        it('should get user subscriptions history', async () => {
            await Purchasely.userSubscriptionsHistory()
            expect(mockedPurchasely.userSubscriptionsHistory).toHaveBeenCalled()
        })

        it('should track subscription content consumed', () => {
            Purchasely.userDidConsumeSubscriptionContent()
            expect(mockedPurchasely.userDidConsumeSubscriptionContent).toHaveBeenCalled()
        })
    })

    describe('Dynamic Offerings', () => {
        it('should set dynamic offering', async () => {
            const offering = {
                reference: 'ref-123',
                planVendorId: 'plan-123',
                offerVendorId: 'offer-123'
            }

            const result = await Purchasely.setDynamicOffering(offering)

            expect(result).toBe(true)
            expect(mockedPurchasely.setDynamicOffering).toHaveBeenCalledWith(
                'ref-123',
                'plan-123',
                'offer-123',
                'unspecified'
            )
        })

        it('should forward the Apple-only billingPlanType when set', async () => {
            await Purchasely.setDynamicOffering({
                reference: 'ref-123',
                planVendorId: 'plan-123',
                offerVendorId: 'offer-123',
                billingPlanType: 'monthly',
            })

            expect(mockedPurchasely.setDynamicOffering).toHaveBeenCalledWith(
                'ref-123',
                'plan-123',
                'offer-123',
                'monthly'
            )
        })

        it('should get dynamic offerings', async () => {
            await Purchasely.getDynamicOfferings()
            expect(mockedPurchasely.getDynamicOfferings).toHaveBeenCalled()
        })

        it('should remove dynamic offering', () => {
            Purchasely.removeDynamicOffering('ref-123')
            expect(mockedPurchasely.removeDynamicOffering).toHaveBeenCalledWith('ref-123')
        })

        it('should clear dynamic offerings', () => {
            Purchasely.clearDynamicOfferings()
            expect(mockedPurchasely.clearDynamicOfferings).toHaveBeenCalled()
        })
    })

    describe('Settings', () => {
        it('should set log level', () => {
            Purchasely.setLogLevel(LogLevels.DEBUG)
            expect(mockedPurchasely.setLogLevel).toHaveBeenCalledWith(mockConstants.logLevelDebug)
        })

        it('should set theme mode', () => {
            Purchasely.setThemeMode(PLYThemeMode.DARK)
            expect(mockedPurchasely.setThemeMode).toHaveBeenCalledWith(mockConstants.themeDark)
        })

        it('should set language', () => {
            Purchasely.setLanguage('fr')
            expect(mockedPurchasely.setLanguage).toHaveBeenCalledWith('fr')
        })

        it('should set debug mode', () => {
            Purchasely.setDebugMode(true)
            expect(mockedPurchasely.setDebugMode).toHaveBeenCalledWith(true)
        })
    })

    // [FLT-W-02 comment / PAR-19] top-level, cross-platform "close everything"
    // entry point — distinct from PLYPresentationRequest#close(), which is
    // scoped to a single request on iOS.
    describe('closeAllScreens', () => {
        it('should close every displayed screen', () => {
            Purchasely.closeAllScreens()
            expect(mockedPurchasely.closeAllScreens).toHaveBeenCalledTimes(1)
        })
    })

    describe('Deeplinks', () => {
        it('should handle a deeplink', async () => {
            const result = await Purchasely.handleDeeplink('purchasely://premium')

            expect(result).toBe(false)
            expect(mockedPurchasely.handleDeeplink).toHaveBeenCalledWith('purchasely://premium')
        })
    })

    describe('GDPR Consent', () => {
        it('should revoke data processing consent', () => {
            Purchasely.revokeDataProcessingConsent([
                PLYDataProcessingPurpose.ANALYTICS,
                PLYDataProcessingPurpose.PERSONALIZATION
            ])

            expect(mockedPurchasely.revokeDataProcessingConsent).toHaveBeenCalledWith([
                'analytics',
                'personalization'
            ])
        })
    })

    describe('Event Listeners', () => {
        it('should add event listener', () => {
            const callback = jest.fn()
            const subscription = Purchasely.addEventListener(callback)

            expect(mockEventEmitter.addListener).toHaveBeenCalledWith(
                'PURCHASELY_EVENTS',
                callback
            )
            expect(subscription).toBeDefined()
        })

        it('should expose Flutter-compatible event listener aliases', () => {
            const eventCallback = jest.fn()
            const purchaseCallback = jest.fn()

            Purchasely.listenToEvents(eventCallback)
            Purchasely.listenToPurchases(purchaseCallback)
            Purchasely.stopListeningToEvents()
            Purchasely.stopListeningToPurchases()

            expect(mockEventEmitter.addListener).toHaveBeenCalledWith(
                'PURCHASELY_EVENTS',
                eventCallback
            )
            expect(mockEventEmitter.addListener).toHaveBeenCalledWith(
                'PURCHASE_LISTENER',
                purchaseCallback
            )
            expect(mockEventEmitter.removeAllListeners).toHaveBeenCalledWith('PURCHASELY_EVENTS')
            expect(mockEventEmitter.removeAllListeners).toHaveBeenCalledWith('PURCHASE_LISTENER')
        })

        it('should remove event listeners', () => {
            Purchasely.removeEventListener()

            expect(mockEventEmitter.removeAllListeners).toHaveBeenCalledWith('PURCHASELY_EVENTS')
        })

        it('should add purchased listener', () => {
            const callback = jest.fn()
            Purchasely.addPurchasedListener(callback)

            expect(mockEventEmitter.addListener).toHaveBeenCalledWith(
                'PURCHASE_LISTENER',
                callback
            )
        })

        it('should remove purchased listener', () => {
            Purchasely.removePurchasedListener()

            expect(mockEventEmitter.removeAllListeners).toHaveBeenCalledWith('PURCHASE_LISTENER')
        })

        it('should add user attribute set listener', () => {
            const callback = jest.fn()
            Purchasely.addUserAttributeSetListener(callback)

            expect(mockEventEmitter.addListener).toHaveBeenCalledWith(
                'USER_ATTRIBUTE_SET_LISTENER',
                callback
            )
        })

        it('should remove user attribute set listener', () => {
            Purchasely.removeUserAttributeSetListener()

            expect(mockEventEmitter.removeAllListeners).toHaveBeenCalledWith('USER_ATTRIBUTE_SET_LISTENER')
        })

        it('should add user attribute removed listener', () => {
            const callback = jest.fn()
            Purchasely.addUserAttributeRemovedListener(callback)

            expect(mockEventEmitter.addListener).toHaveBeenCalledWith(
                'USER_ATTRIBUTE_REMOVED_LISTENER',
                callback
            )
        })

        it('should remove user attribute removed listener', () => {
            Purchasely.removeUserAttributeRemovedListener()

            expect(mockEventEmitter.removeAllListeners).toHaveBeenCalledWith('USER_ATTRIBUTE_REMOVED_LISTENER')
        })

        it('should expose a Flutter-compatible combined user attribute listener', () => {
            const listener = {
                onUserAttributeSet: jest.fn(),
                onUserAttributeRemoved: jest.fn(),
            }

            Purchasely.setUserAttributeListener(listener)

            expect(mockEventEmitter.addListener).toHaveBeenCalledWith(
                'USER_ATTRIBUTE_SET_LISTENER',
                expect.any(Function)
            )
            expect(mockEventEmitter.addListener).toHaveBeenCalledWith(
                'USER_ATTRIBUTE_REMOVED_LISTENER',
                expect.any(Function)
            )

            Purchasely.clearUserAttributeListener()
            expect(mockEventEmitter.removeAllListeners).toHaveBeenCalledWith('USER_ATTRIBUTE_SET_LISTENER')
            expect(mockEventEmitter.removeAllListeners).toHaveBeenCalledWith('USER_ATTRIBUTE_REMOVED_LISTENER')
        })
    })

    describe('Synchronization', () => {
        it('should call synchronize', () => {
            Purchasely.synchronize()
            expect(mockedPurchasely.synchronize).toHaveBeenCalled()
        })

        it('should resolve when the native synchronize succeeds', async () => {
            mockedPurchasely.synchronize.mockResolvedValueOnce(true)
            await expect(Purchasely.synchronize()).resolves.toBe(true)
        })

        it('should reject when the native synchronize fails', async () => {
            const error = new Error('No store configured')
            mockedPurchasely.synchronize.mockRejectedValueOnce(error)
            await expect(Purchasely.synchronize()).rejects.toBe(error)
        })
    })
})
