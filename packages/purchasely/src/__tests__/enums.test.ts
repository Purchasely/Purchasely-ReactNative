/**
 * Unit tests for Purchasely React Native SDK enums
 */

import { mockConstants } from '../__mocks__/testUtils'

// Mock react-native before importing enums
jest.mock('react-native', () => ({
    NativeModules: {
        Purchasely: {
            getConstants: jest.fn(() => mockConstants),
        },
    },
}))

import {
    ProductResult,
    LogLevels,
    SubscriptionSource,
    Attributes,
    PlanType,
    RunningMode,
    PLYThemeMode,
    PLYPaywallAction,
    PLYDataProcessingLegalBasis,
    PLYDataProcessingPurpose,
    PLYPresentationType,
    PLYUserAttributeSource,
    PLYUserAttributeType,
    PLYWebCheckoutProvider,
} from '../enums'

describe('Purchasely Enums', () => {
    describe('ProductResult', () => {
        it('should have correct enum values from constants', () => {
            expect(ProductResult.PRODUCT_RESULT_PURCHASED).toBe(mockConstants.productResultPurchased)
            expect(ProductResult.PRODUCT_RESULT_CANCELLED).toBe(mockConstants.productResultCancelled)
            expect(ProductResult.PRODUCT_RESULT_RESTORED).toBe(mockConstants.productResultRestored)
        })

        it('should have all expected members', () => {
            const members = Object.keys(ProductResult).filter(key => isNaN(Number(key)))
            expect(members).toContain('PRODUCT_RESULT_PURCHASED')
            expect(members).toContain('PRODUCT_RESULT_CANCELLED')
            expect(members).toContain('PRODUCT_RESULT_RESTORED')
            expect(members).toHaveLength(3)
        })
    })

    describe('LogLevels', () => {
        it('should have correct enum values from constants', () => {
            expect(LogLevels.DEBUG).toBe(mockConstants.logLevelDebug)
            expect(LogLevels.INFO).toBe(mockConstants.logLevelInfo)
            expect(LogLevels.WARNING).toBe(mockConstants.logLevelWarn)
            expect(LogLevels.ERROR).toBe(mockConstants.logLevelError)
        })

        it('should have all expected members', () => {
            const members = Object.keys(LogLevels).filter(key => isNaN(Number(key)))
            expect(members).toContain('DEBUG')
            expect(members).toContain('INFO')
            expect(members).toContain('WARNING')
            expect(members).toContain('ERROR')
            expect(members).toHaveLength(4)
        })
    })

    describe('SubscriptionSource', () => {
        it('should have correct enum values from constants', () => {
            expect(SubscriptionSource.APPLE_APP_STORE).toBe(mockConstants.sourceAppStore)
            expect(SubscriptionSource.GOOGLE_PLAY_STORE).toBe(mockConstants.sourcePlayStore)
            expect(SubscriptionSource.HUAWEI_APP_GALLERY).toBe(mockConstants.sourceHuaweiAppGallery)
            expect(SubscriptionSource.AMAZON_APPSTORE).toBe(mockConstants.sourceAmazonAppstore)
        })

        it('should have all expected members', () => {
            const members = Object.keys(SubscriptionSource).filter(key => isNaN(Number(key)))
            expect(members).toContain('APPLE_APP_STORE')
            expect(members).toContain('GOOGLE_PLAY_STORE')
            expect(members).toContain('HUAWEI_APP_GALLERY')
            expect(members).toContain('AMAZON_APPSTORE')
            expect(members).toHaveLength(4)
        })
    })

    describe('Attributes', () => {
        it('should have marketing attribution attributes from constants', () => {
            expect(Attributes.FIREBASE_APP_INSTANCE_ID).toBe(mockConstants.firebaseAppInstanceId)
            expect(Attributes.AIRSHIP_CHANNEL_ID).toBe(mockConstants.airshipChannelId)
            expect(Attributes.AIRSHIP_USER_ID).toBe(mockConstants.airshipUserId)
            expect(Attributes.BATCH_INSTALLATION_ID).toBe(mockConstants.batchInstallationId)
            expect(Attributes.ADJUST_ID).toBe(mockConstants.adjustId)
            expect(Attributes.APPSFLYER_ID).toBe(mockConstants.appsflyerId)
            expect(Attributes.ONESIGNAL_PLAYER_ID).toBe(mockConstants.onesignalPlayerId)
            expect(Attributes.MIXPANEL_DISTINCT_ID).toBe(mockConstants.mixpanelDistinctId)
            expect(Attributes.CLEVER_TAP_ID).toBe(mockConstants.clevertapId)
        })

        it('should have email-based attributes from constants', () => {
            expect(Attributes.SENDINBLUE_USER_EMAIL).toBe(mockConstants.sendinblueUserEmail)
            expect(Attributes.ITERABLE_USER_EMAIL).toBe(mockConstants.iterableUserEmail)
            expect(Attributes.CUSTOMER_IO_USER_EMAIL).toBe(mockConstants.customerIoUserEmail)
        })

        it('should have all 21 expected members', () => {
            const members = Object.keys(Attributes).filter(key => isNaN(Number(key)))
            expect(members).toHaveLength(21)
        })
    })

    describe('PlanType', () => {
        it('should have correct enum values from constants', () => {
            expect(PlanType.PLAN_TYPE_CONSUMABLE).toBe(mockConstants.consumable)
            expect(PlanType.PLAN_TYPE_NON_CONSUMABLE).toBe(mockConstants.nonConsumable)
            expect(PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION).toBe(mockConstants.autoRenewingSubscription)
            expect(PlanType.PLAN_TYPE_NON_RENEWING_SUBSCRIPTION).toBe(mockConstants.nonRenewingSubscription)
            expect(PlanType.PLAN_TYPE_UNKNOWN).toBe(mockConstants.unknown)
        })

        it('should have all expected members', () => {
            const members = Object.keys(PlanType).filter(key => isNaN(Number(key)))
            expect(members).toContain('PLAN_TYPE_CONSUMABLE')
            expect(members).toContain('PLAN_TYPE_NON_CONSUMABLE')
            expect(members).toContain('PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION')
            expect(members).toContain('PLAN_TYPE_NON_RENEWING_SUBSCRIPTION')
            expect(members).toContain('PLAN_TYPE_UNKNOWN')
            expect(members).toHaveLength(5)
        })
    })

    describe('RunningMode', () => {
        it('should have correct enum values from constants', () => {
            expect(RunningMode.TRANSACTION_ONLY).toBe(mockConstants.runningModeTransactionOnly)
            expect(RunningMode.OBSERVER).toBe(mockConstants.runningModeObserver)
            expect(RunningMode.PAYWALL_OBSERVER).toBe(mockConstants.runningModePaywallObserver)
            expect(RunningMode.FULL).toBe(mockConstants.runningModeFull)
        })

        it('should have all expected members', () => {
            const members = Object.keys(RunningMode).filter(key => isNaN(Number(key)))
            expect(members).toContain('TRANSACTION_ONLY')
            expect(members).toContain('OBSERVER')
            expect(members).toContain('PAYWALL_OBSERVER')
            expect(members).toContain('FULL')
            expect(members).toHaveLength(4)
        })
    })

    describe('PLYThemeMode', () => {
        it('should have correct enum values from constants', () => {
            expect(PLYThemeMode.LIGHT).toBe(mockConstants.themeLight)
            expect(PLYThemeMode.DARK).toBe(mockConstants.themeDark)
            expect(PLYThemeMode.SYSTEM).toBe(mockConstants.themeSystem)
        })

        it('should have all expected members', () => {
            const members = Object.keys(PLYThemeMode).filter(key => isNaN(Number(key)))
            expect(members).toContain('LIGHT')
            expect(members).toContain('DARK')
            expect(members).toContain('SYSTEM')
            expect(members).toHaveLength(3)
        })
    })

    describe('PLYPaywallAction', () => {
        it('should have string enum values', () => {
            expect(PLYPaywallAction.CLOSE).toBe('close')
            expect(PLYPaywallAction.CLOSE_ALL).toBe('closeAll')
            expect(PLYPaywallAction.LOGIN).toBe('login')
            expect(PLYPaywallAction.NAVIGATE).toBe('navigate')
            expect(PLYPaywallAction.PURCHASE).toBe('purchase')
            expect(PLYPaywallAction.RESTORE).toBe('restore')
            expect(PLYPaywallAction.OPEN_PRESENTATION).toBe('open_presentation')
            expect(PLYPaywallAction.OPEN_PLACEMENT).toBe('open_placement')
            expect(PLYPaywallAction.PROMO_CODE).toBe('promo_code')
            expect(PLYPaywallAction.OPEN_FLOW_STEP).toBe('open_flow_step')
            expect(PLYPaywallAction.WEB_CHECKOUT).toBe('web_checkout')
        })

        it('should have all expected members', () => {
            const values = Object.values(PLYPaywallAction)
            expect(values).toContain('close')
            expect(values).toContain('closeAll')
            expect(values).toContain('login')
            expect(values).toContain('navigate')
            expect(values).toContain('purchase')
            expect(values).toContain('restore')
            expect(values).toContain('open_presentation')
            expect(values).toContain('open_placement')
            expect(values).toContain('promo_code')
            expect(values).toContain('open_flow_step')
            expect(values).toContain('web_checkout')
            expect(values).toHaveLength(11)
        })
    })

    describe('PLYDataProcessingLegalBasis', () => {
        it('should have string enum values', () => {
            expect(PLYDataProcessingLegalBasis.ESSENTIAL).toBe('ESSENTIAL')
            expect(PLYDataProcessingLegalBasis.OPTIONAL).toBe('OPTIONAL')
        })

        it('should have all expected members', () => {
            const values = Object.values(PLYDataProcessingLegalBasis)
            expect(values).toContain('ESSENTIAL')
            expect(values).toContain('OPTIONAL')
            expect(values).toHaveLength(2)
        })
    })

    describe('PLYDataProcessingPurpose', () => {
        it('should have string enum values', () => {
            expect(PLYDataProcessingPurpose.ANALYTICS).toBe('analytics')
            expect(PLYDataProcessingPurpose.IDENTIFIED_ANALYTICS).toBe('identified-analytics')
            expect(PLYDataProcessingPurpose.CAMPAIGNS).toBe('campaigns')
            expect(PLYDataProcessingPurpose.PERSONALIZATION).toBe('personalization')
            expect(PLYDataProcessingPurpose.THIRD_PARTY_INTEGRATION).toBe('third-party-integration')
            expect(PLYDataProcessingPurpose.ALL_NON_ESSENTIALS).toBe('all-non-essentials')
        })

        it('should have all expected members', () => {
            const values = Object.values(PLYDataProcessingPurpose)
            expect(values).toContain('analytics')
            expect(values).toContain('identified-analytics')
            expect(values).toContain('campaigns')
            expect(values).toContain('personalization')
            expect(values).toContain('third-party-integration')
            expect(values).toContain('all-non-essentials')
            expect(values).toHaveLength(6)
        })
    })

    describe('PLYPresentationType', () => {
        it('should have correct enum values from constants', () => {
            expect(PLYPresentationType.NORMAL).toBe(mockConstants.presentationTypeNormal)
            expect(PLYPresentationType.FALLBACK).toBe(mockConstants.presentationTypeFallback)
            expect(PLYPresentationType.DEACTIVATED).toBe(mockConstants.presentationTypeDeactivated)
            expect(PLYPresentationType.CLIENT).toBe(mockConstants.presentationTypeClient)
        })

        it('should have all expected members', () => {
            const members = Object.keys(PLYPresentationType).filter(key => isNaN(Number(key)))
            expect(members).toContain('NORMAL')
            expect(members).toContain('FALLBACK')
            expect(members).toContain('DEACTIVATED')
            expect(members).toContain('CLIENT')
            expect(members).toHaveLength(4)
        })
    })

    describe('PLYUserAttributeSource', () => {
        it('should have correct enum values from constants', () => {
            expect(PLYUserAttributeSource.PURCHASELY).toBe(mockConstants.userAttributeSourcePurchasely)
            expect(PLYUserAttributeSource.CLIENT).toBe(mockConstants.userAttributeSourceClient)
        })

        it('should have all expected members', () => {
            const members = Object.keys(PLYUserAttributeSource).filter(key => isNaN(Number(key)))
            expect(members).toContain('PURCHASELY')
            expect(members).toContain('CLIENT')
            expect(members).toHaveLength(2)
        })
    })

    describe('PLYUserAttributeType', () => {
        it('should have correct enum values from constants', () => {
            expect(PLYUserAttributeType.STRING).toBe(mockConstants.userAttributeString)
            expect(PLYUserAttributeType.BOOLEAN).toBe(mockConstants.userAttributeBoolean)
            expect(PLYUserAttributeType.INT).toBe(mockConstants.userAttributeInt)
            expect(PLYUserAttributeType.FLOAT).toBe(mockConstants.userAttributeFloat)
            expect(PLYUserAttributeType.DATE).toBe(mockConstants.userAttributeDate)
            expect(PLYUserAttributeType.STRING_ARRAY).toBe(mockConstants.userAttributeStringArray)
            expect(PLYUserAttributeType.INT_ARRAY).toBe(mockConstants.userAttributeIntArray)
            expect(PLYUserAttributeType.FLOAT_ARRAY).toBe(mockConstants.userAttributeFloatArray)
            expect(PLYUserAttributeType.BOOLEAN_ARRAY).toBe(mockConstants.userAttributeBooleanArray)
        })

        it('should have all expected members', () => {
            const members = Object.keys(PLYUserAttributeType).filter(key => isNaN(Number(key)))
            expect(members).toContain('STRING')
            expect(members).toContain('BOOLEAN')
            expect(members).toContain('INT')
            expect(members).toContain('FLOAT')
            expect(members).toContain('DATE')
            expect(members).toContain('STRING_ARRAY')
            expect(members).toContain('INT_ARRAY')
            expect(members).toContain('FLOAT_ARRAY')
            expect(members).toContain('BOOLEAN_ARRAY')
            expect(members).toHaveLength(9)
        })
    })

    describe('PLYWebCheckoutProvider', () => {
        it('should have string enum values', () => {
            expect(PLYWebCheckoutProvider.STRIPE).toBe('stripe')
            expect(PLYWebCheckoutProvider.OTHER).toBe('other')
        })

        it('should have all expected members', () => {
            const values = Object.values(PLYWebCheckoutProvider)
            expect(values).toContain('stripe')
            expect(values).toContain('other')
            expect(values).toHaveLength(2)
        })
    })
})
