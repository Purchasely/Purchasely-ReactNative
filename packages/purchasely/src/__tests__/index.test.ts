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
            close: jest.fn(),
            userLogin: jest.fn().mockResolvedValue(true),
            userLogout: jest.fn(),
            isAnonymous: jest.fn().mockResolvedValue(false),
            getAnonymousUserId: jest.fn().mockResolvedValue('anonymous-user-id'),
            setLogLevel: jest.fn(),
            readyToOpenDeeplink: jest.fn(),
            setAttribute: jest.fn(),
            setLanguage: jest.fn(),
            synchronize: jest.fn(),
            fetchPresentation: jest.fn().mockResolvedValue({
                id: 'presentation-id',
                placementId: 'placement-id',
                type: 0,
                plans: [],
                metadata: {},
                height: null,
            }),
            presentPresentation: jest.fn().mockResolvedValue({
                result: 0,
                plan: null,
            }),
            presentPresentationWithIdentifier: jest.fn().mockResolvedValue({
                result: 0,
                plan: null,
            }),
            presentPresentationForPlacement: jest.fn().mockResolvedValue({
                result: 0,
                plan: null,
            }),
            presentProductWithIdentifier: jest.fn().mockResolvedValue({
                result: 0,
                plan: null,
            }),
            presentPlanWithIdentifier: jest.fn().mockResolvedValue({
                result: 0,
                plan: null,
            }),
            closePresentation: jest.fn(),
            hidePresentation: jest.fn(),
            showPresentation: jest.fn(),
            presentSubscriptions: jest.fn(),
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
            isDeeplinkHandled: jest.fn().mockResolvedValue(false),
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
            clearBuiltInAttributes: jest.fn(),
            setDefaultPresentationResultHandler: jest.fn().mockResolvedValue({
                result: 0,
                plan: null,
            }),
            setPaywallActionInterceptor: jest.fn().mockResolvedValue({
                info: {},
                action: 'close',
                parameters: {},
            }),
            onProcessAction: jest.fn(),
            clientPresentationDisplayed: jest.fn(),
            clientPresentationClosed: jest.fn(),
            userDidConsumeSubscriptionContent: jest.fn(),
            setThemeMode: jest.fn(),
            setDynamicOffering: jest.fn().mockResolvedValue(true),
            getDynamicOfferings: jest.fn().mockResolvedValue([]),
            removeDynamicOffering: jest.fn(),
            clearDynamicOfferings: jest.fn(),
            revokeDataProcessingConsent: jest.fn(),
            setDebugMode: jest.fn(),
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
import Purchasely from '../index'
import { LogLevels, RunningMode, PLYThemeMode, PLYDataProcessingLegalBasis, PLYDataProcessingPurpose } from '../enums'
import { NativeModules } from 'react-native'

// Get reference to the mocked module
const mockedPurchasely = NativeModules.Purchasely

describe('Purchasely SDK', () => {
    beforeEach(() => {
        jest.clearAllMocks()
    })

    describe('Initialization', () => {
        it('should call native start with correct parameters', async () => {
            const params = {
                apiKey: 'test-api-key',
                androidStores: ['Google'],
                storeKit1: false,
                userId: 'test-user',
                logLevel: LogLevels.DEBUG,
                runningMode: RunningMode.FULL,
            }

            const result = await Purchasely.start(params)

            expect(result).toBe(true)
            expect(mockedPurchasely.start).toHaveBeenCalledWith(
                'test-api-key',
                ['Google'],
                false,
                'test-user',
                mockConstants.logLevelDebug,
                mockConstants.runningModeFull,
                '5.6.2'
            )
        })

        it('should use default values when optional params not provided', async () => {
            const params = {
                apiKey: 'test-api-key',
                storeKit1: true,
                logLevel: LogLevels.ERROR,
                runningMode: RunningMode.FULL,
            }

            await Purchasely.start(params)

            expect(mockedPurchasely.start).toHaveBeenCalledWith(
                'test-api-key',
                ['Google'],
                true,
                null,
                mockConstants.logLevelError,
                mockConstants.runningModeFull,
                '5.6.2'
            )
        })

        it('should return constants from getConstants', () => {
            const constants = Purchasely.getConstants()
            expect(constants).toEqual(mockConstants)
        })

        it('should call native close', () => {
            Purchasely.close()
            expect(mockedPurchasely.close).toHaveBeenCalled()
        })
    })

    describe('User Management', () => {
        it('should call userLogin with userId', async () => {
            const result = await Purchasely.userLogin('user-123')

            expect(result).toBe(true)
            expect(mockedPurchasely.userLogin).toHaveBeenCalledWith('user-123')
        })

        it('should call userLogout', () => {
            Purchasely.userLogout()
            expect(mockedPurchasely.userLogout).toHaveBeenCalled()
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
    })

    describe('Presentations', () => {
        it('should fetch presentation with placementId', async () => {
            const result = await Purchasely.fetchPresentation({ placementId: 'onboarding' })

            expect(result.id).toBe('presentation-id')
            expect(mockedPurchasely.fetchPresentation).toHaveBeenCalledWith(
                'onboarding',
                null,
                null
            )
        })

        it('should fetch presentation with presentationId', async () => {
            await Purchasely.fetchPresentation({ presentationId: 'pres-123' })

            expect(mockedPurchasely.fetchPresentation).toHaveBeenCalledWith(
                null,
                'pres-123',
                null
            )
        })

        it('should fetch presentation with contentId', async () => {
            await Purchasely.fetchPresentation({
                placementId: 'onboarding',
                contentId: 'content-123'
            })

            expect(mockedPurchasely.fetchPresentation).toHaveBeenCalledWith(
                'onboarding',
                null,
                'content-123'
            )
        })

        it('should present presentation', async () => {
            const presentation = { id: 'pres-123', metadata: {}, height: null }
            await Purchasely.presentPresentation({ presentation })

            expect(mockedPurchasely.presentPresentation).toHaveBeenCalledWith(
                presentation,
                false,
                null
            )
        })

        it('should present presentation fullscreen', async () => {
            await Purchasely.presentPresentation({ isFullscreen: true })

            expect(mockedPurchasely.presentPresentation).toHaveBeenCalledWith(
                null,
                true,
                null
            )
        })

        it('should present presentation with loading background color', async () => {
            await Purchasely.presentPresentation({ loadingBackgroundColor: '#FF0000' })

            expect(mockedPurchasely.presentPresentation).toHaveBeenCalledWith(
                null,
                false,
                '#FF0000'
            )
        })

        it('should present presentation with identifier', async () => {
            await Purchasely.presentPresentationWithIdentifier({
                presentationVendorId: 'premium',
                isFullscreen: true
            })

            expect(mockedPurchasely.presentPresentationWithIdentifier).toHaveBeenCalledWith(
                'premium',
                null,
                true,
                null
            )
        })

        it('should present presentation for placement', async () => {
            await Purchasely.presentPresentationForPlacement({
                placementVendorId: 'onboarding',
                contentId: 'content-123'
            })

            expect(mockedPurchasely.presentPresentationForPlacement).toHaveBeenCalledWith(
                'onboarding',
                'content-123',
                false,
                null
            )
        })

        it('should present product with identifier', async () => {
            await Purchasely.presentProductWithIdentifier({
                productVendorId: 'premium-product'
            })

            expect(mockedPurchasely.presentProductWithIdentifier).toHaveBeenCalledWith(
                'premium-product',
                null,
                null,
                false,
                null
            )
        })

        it('should present plan with identifier', async () => {
            await Purchasely.presentPlanWithIdentifier({
                planVendorId: 'monthly-plan'
            })

            expect(mockedPurchasely.presentPlanWithIdentifier).toHaveBeenCalledWith(
                'monthly-plan',
                null,
                null,
                false,
                null
            )
        })

        it('should close presentation', () => {
            Purchasely.closePresentation()
            expect(mockedPurchasely.closePresentation).toHaveBeenCalled()
        })

        it('should hide presentation', () => {
            Purchasely.hidePresentation()
            expect(mockedPurchasely.hidePresentation).toHaveBeenCalled()
        })

        it('should show presentation', () => {
            Purchasely.showPresentation()
            expect(mockedPurchasely.showPresentation).toHaveBeenCalled()
        })

        it('should present subscriptions', () => {
            Purchasely.presentSubscriptions()
            expect(mockedPurchasely.presentSubscriptions).toHaveBeenCalled()
        })

        it('should track client presentation displayed', () => {
            const presentation = { id: 'pres-123', metadata: {}, height: null }
            Purchasely.clientPresentationDisplayed(presentation as any)
            expect(mockedPurchasely.clientPresentationDisplayed).toHaveBeenCalledWith(presentation)
        })

        it('should track client presentation closed', () => {
            const presentation = { id: 'pres-123', metadata: {}, height: null }
            Purchasely.clientPresentationClosed(presentation as any)
            expect(mockedPurchasely.clientPresentationClosed).toHaveBeenCalledWith(presentation)
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

            expect(result.planVendorId).toBe('plan-id')
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
                'offer-123'
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

    describe('Deeplinks', () => {
        it('should set ready to open deeplink', () => {
            Purchasely.readyToOpenDeeplink(true)
            expect(mockedPurchasely.readyToOpenDeeplink).toHaveBeenCalledWith(true)
        })

        it('should check if deeplink is handled', async () => {
            const result = await Purchasely.isDeeplinkHandled('purchasely://premium')

            expect(result).toBe(false)
            expect(mockedPurchasely.isDeeplinkHandled).toHaveBeenCalledWith('purchasely://premium')
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
    })

    describe('Action Handlers', () => {
        it('should call onProcessAction', () => {
            Purchasely.onProcessAction(true)
            expect(mockedPurchasely.onProcessAction).toHaveBeenCalledWith(true)
        })

        it('should call setDefaultPresentationResultHandler', async () => {
            await Purchasely.setDefaultPresentationResultHandler()
            expect(mockedPurchasely.setDefaultPresentationResultHandler).toHaveBeenCalled()
        })

        it('should call setPaywallActionInterceptor', async () => {
            await Purchasely.setPaywallActionInterceptor()
            expect(mockedPurchasely.setPaywallActionInterceptor).toHaveBeenCalled()
        })
    })

    describe('Synchronization', () => {
        it('should call synchronize', () => {
            Purchasely.synchronize()
            expect(mockedPurchasely.synchronize).toHaveBeenCalled()
        })
    })
})
