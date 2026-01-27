/**
 * Unit tests for Purchasely React Native SDK type definitions
 * These tests verify that types are correctly defined and usable
 */

import { mockConstants } from '../__mocks__/testUtils'

// Mock react-native before importing types
jest.mock('react-native', () => ({
    NativeModules: {
        Purchasely: {
            getConstants: jest.fn(() => mockConstants),
        },
    },
}))

import type {
    PurchaselyPlan,
    PurchaselyProduct,
    PurchaselySubscription,
    PurchaselyPromotionalOfferSignature,
    PurchaselyUserAttribute,
    PresentPresentationResult,
    PaywallActionInterceptorResult,
    PurchaselyEvent,
    PurchaselyPresentation,
    PLYPaywallInfo,
    PLYPresentationPlan,
    PLYPresentationMetadata,
    PurchaselyOffer,
    PurchaselySubscriptionOffer,
} from '../types'

import {
    PlanType,
    ProductResult,
    SubscriptionSource,
    PLYPaywallAction,
    PLYPresentationType,
    PLYUserAttributeSource,
    PLYUserAttributeType,
    PLYWebCheckoutProvider,
    PLYDataProcessingLegalBasis,
} from '../enums'

describe('Purchasely Types', () => {
    describe('PurchaselyPlan', () => {
        it('should accept valid plan object', () => {
            const plan: PurchaselyPlan = {
                vendorId: 'monthly-plan',
                productId: 'product-123',
                name: 'Monthly Subscription',
                type: PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION,
                amount: 999,
                localizedAmount: '$9.99',
                currencyCode: 'USD',
                currencySymbol: '$',
                price: '$9.99/month',
                period: 'P1M',
                hasIntroductoryPrice: true,
                introPrice: '$4.99',
                introAmount: 499,
                introDuration: '1 month',
                introPeriod: 'P1M',
                hasFreeTrial: false,
            }

            expect(plan.vendorId).toBe('monthly-plan')
            expect(plan.type).toBe(PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION)
            expect(plan.hasIntroductoryPrice).toBe(true)
        })

        it('should handle consumable plan type', () => {
            const plan: PurchaselyPlan = {
                vendorId: 'coins-100',
                productId: 'coins-product',
                name: '100 Coins',
                type: PlanType.PLAN_TYPE_CONSUMABLE,
                amount: 199,
                localizedAmount: '$1.99',
                currencyCode: 'USD',
                currencySymbol: '$',
                price: '$1.99',
                period: '',
                hasIntroductoryPrice: false,
                introPrice: '',
                introAmount: 0,
                introDuration: '',
                introPeriod: '',
                hasFreeTrial: false,
            }

            expect(plan.type).toBe(PlanType.PLAN_TYPE_CONSUMABLE)
        })
    })

    describe('PurchaselyProduct', () => {
        it('should accept valid product object', () => {
            const product: PurchaselyProduct = {
                name: 'Premium Subscription',
                vendorId: 'premium-product',
                plans: [
                    {
                        vendorId: 'monthly-plan',
                        productId: 'premium-product',
                        name: 'Monthly',
                        type: PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION,
                        amount: 999,
                        localizedAmount: '$9.99',
                        currencyCode: 'USD',
                        currencySymbol: '$',
                        price: '$9.99/month',
                        period: 'P1M',
                        hasIntroductoryPrice: false,
                        introPrice: '',
                        introAmount: 0,
                        introDuration: '',
                        introPeriod: '',
                        hasFreeTrial: true,
                    },
                ],
            }

            expect(product.name).toBe('Premium Subscription')
            expect(product.plans).toHaveLength(1)
            expect(product.plans?.[0]?.hasFreeTrial).toBe(true)
        })

        it('should handle product with empty plans array', () => {
            const product: PurchaselyProduct = {
                name: 'Empty Product',
                vendorId: 'empty-product',
                plans: [],
            }

            expect(product.plans).toHaveLength(0)
        })
    })

    describe('PurchaselySubscription', () => {
        it('should accept valid subscription object', () => {
            const subscription: PurchaselySubscription = {
                purchaseToken: 'token-123',
                subscriptionSource: SubscriptionSource.APPLE_APP_STORE,
                nextRenewalDate: '2024-02-15T12:00:00Z',
                cancelledDate: '',
                plan: {
                    vendorId: 'monthly-plan',
                    productId: 'premium-product',
                    name: 'Monthly',
                    type: PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION,
                    amount: 999,
                    localizedAmount: '$9.99',
                    currencyCode: 'USD',
                    currencySymbol: '$',
                    price: '$9.99/month',
                    period: 'P1M',
                    hasIntroductoryPrice: false,
                    introPrice: '',
                    introAmount: 0,
                    introDuration: '',
                    introPeriod: '',
                    hasFreeTrial: false,
                },
                product: {
                    name: 'Premium',
                    vendorId: 'premium-product',
                    plans: [],
                },
            }

            expect(subscription.subscriptionSource).toBe(SubscriptionSource.APPLE_APP_STORE)
            expect(subscription.nextRenewalDate).toBe('2024-02-15T12:00:00Z')
        })
    })

    describe('PurchaselyPromotionalOfferSignature', () => {
        it('should accept valid signature object', () => {
            const signature: PurchaselyPromotionalOfferSignature = {
                planVendorId: 'plan-123',
                identifier: 'offer-id',
                signature: 'base64-signature',
                nonce: 'uuid-nonce',
                keyIdentifier: 'key-id',
                timestamp: 1705315200000,
            }

            expect(signature.planVendorId).toBe('plan-123')
            expect(signature.timestamp).toBeGreaterThan(0)
        })
    })

    describe('PurchaselyUserAttribute', () => {
        it('should accept user attribute with all fields', () => {
            const attr: PurchaselyUserAttribute = {
                key: 'name',
                value: 'John Doe',
                type: PLYUserAttributeType.STRING,
                source: PLYUserAttributeSource.CLIENT,
                legalBasis: PLYDataProcessingLegalBasis.ESSENTIAL,
            }

            expect(attr.key).toBe('name')
            expect(attr.type).toBe(PLYUserAttributeType.STRING)
        })

        it('should accept user attribute with optional fields null', () => {
            const attr: PurchaselyUserAttribute = {
                key: 'counter',
                value: null,
                type: null,
                source: null,
            }

            expect(attr.value).toBeNull()
        })
    })

    describe('PresentPresentationResult', () => {
        it('should accept valid result object', () => {
            const result: PresentPresentationResult = {
                result: ProductResult.PRODUCT_RESULT_PURCHASED,
                plan: {
                    vendorId: 'plan-123',
                    productId: 'product-123',
                    name: 'Plan',
                    type: PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION,
                    amount: 999,
                    localizedAmount: '$9.99',
                    currencyCode: 'USD',
                    currencySymbol: '$',
                    price: '$9.99',
                    period: 'P1M',
                    hasIntroductoryPrice: false,
                    introPrice: '',
                    introAmount: 0,
                    introDuration: '',
                    introPeriod: '',
                    hasFreeTrial: false,
                },
            }

            expect(result.result).toBe(ProductResult.PRODUCT_RESULT_PURCHASED)
        })
    })

    describe('PaywallActionInterceptorResult', () => {
        it('should accept valid interceptor result', () => {
            const result: PaywallActionInterceptorResult = {
                info: {
                    presentationId: 'pres-123',
                    placementId: 'placement-123',
                    contentId: 'content-123',
                    abTestId: 'ab-123',
                    abTestVariantId: 'variant-a',
                },
                action: PLYPaywallAction.PURCHASE,
                parameters: {
                    clientReferenceId: 'ref-123',
                    url: 'https://example.com',
                    title: 'Purchase',
                    plan: {} as any,
                    offer: null,
                    subscriptionOffer: null,
                    presentation: 'pres-123',
                    queryParameterKey: 'param',
                    webCheckoutProvider: PLYWebCheckoutProvider.STRIPE,
                },
            }

            expect(result.action).toBe(PLYPaywallAction.PURCHASE)
            expect(result.info.presentationId).toBe('pres-123')
        })
    })

    describe('PurchaselyPresentation', () => {
        it('should accept valid presentation object', () => {
            const presentation: PurchaselyPresentation = {
                id: 'pres-123',
                placementId: 'placement-123',
                audienceId: 'audience-123',
                abTestId: 'ab-123',
                abTestVariantId: 'variant-a',
                language: 'en',
                type: PLYPresentationType.NORMAL,
                plans: [
                    {
                        planVendorId: 'plan-123',
                        storeProductId: 'store-product-123',
                        basePlanId: 'base-plan',
                        offerId: 'offer-123',
                    },
                ],
                metadata: {
                    title: 'Premium Access',
                    showDiscount: true,
                    discountPercent: 20,
                },
                height: 500,
            }

            expect(presentation.id).toBe('pres-123')
            expect(presentation.type).toBe(PLYPresentationType.NORMAL)
            expect(presentation.metadata.title).toBe('Premium Access')
        })

        it('should accept presentation with null optional fields', () => {
            const presentation: PurchaselyPresentation = {
                id: 'pres-123',
                placementId: null,
                audienceId: null,
                abTestId: null,
                abTestVariantId: null,
                language: null,
                type: null,
                plans: null,
                metadata: {},
                height: null,
            }

            expect(presentation.placementId).toBeNull()
            expect(presentation.height).toBeNull()
        })
    })

    describe('PurchaselyEvent', () => {
        it('should accept valid event object', () => {
            const event: PurchaselyEvent = {
                name: 'PURCHASE_TAPPED',
                properties: {
                    sdk_version: '5.6.2',
                    event_name: 'PURCHASE_TAPPED',
                    event_created_at_ms: 1705315200000,
                    event_created_at: '2024-01-15T12:00:00Z',
                    user_id: 'user-123',
                    displayed_presentation: 'pres-123',
                    selected_plan: 'monthly-plan',
                },
            }

            expect(event.name).toBe('PURCHASE_TAPPED')
            expect(event.properties.sdk_version).toBe('5.6.2')
        })
    })

    describe('PLYPaywallInfo', () => {
        it('should accept valid paywall info', () => {
            const info: PLYPaywallInfo = {
                presentationId: 'pres-123',
                placementId: 'placement-123',
                contentId: 'content-123',
                abTestId: 'ab-123',
                abTestVariantId: 'variant-a',
            }

            expect(info.presentationId).toBe('pres-123')
        })

        it('should accept empty paywall info', () => {
            const info: PLYPaywallInfo = {}

            expect(info.presentationId).toBeUndefined()
        })
    })

    describe('PLYPresentationPlan', () => {
        it('should accept valid presentation plan', () => {
            const plan: PLYPresentationPlan = {
                planVendorId: 'plan-123',
                storeProductId: 'store-product-123',
                basePlanId: 'base-plan',
                offerId: 'offer-123',
            }

            expect(plan.planVendorId).toBe('plan-123')
        })

        it('should accept presentation plan with null fields', () => {
            const plan: PLYPresentationPlan = {
                planVendorId: null,
                storeProductId: null,
                basePlanId: null,
                offerId: null,
            }

            expect(plan.planVendorId).toBeNull()
        })
    })

    describe('PLYPresentationMetadata', () => {
        it('should accept various value types', () => {
            const metadata: PLYPresentationMetadata = {
                title: 'Premium',
                showBanner: true,
                discountPercent: 20,
            }

            expect(metadata.title).toBe('Premium')
            expect(metadata.showBanner).toBe(true)
            expect(metadata.discountPercent).toBe(20)
        })
    })

    describe('PurchaselyOffer', () => {
        it('should accept valid offer', () => {
            const offer: PurchaselyOffer = {
                vendorId: 'offer-123',
                storeOfferId: 'store-offer-123',
            }

            expect(offer.vendorId).toBe('offer-123')
        })

        it('should accept offer with null fields', () => {
            const offer: PurchaselyOffer = {
                vendorId: null,
                storeOfferId: null,
            }

            expect(offer.vendorId).toBeNull()
        })
    })

    describe('PurchaselySubscriptionOffer', () => {
        it('should accept valid subscription offer', () => {
            const offer: PurchaselySubscriptionOffer = {
                subscriptionId: 'sub-123',
                basePlanId: 'base-plan',
                offerToken: 'token-123',
                offerId: 'offer-123',
            }

            expect(offer.subscriptionId).toBe('sub-123')
        })

        it('should accept subscription offer with null optional fields', () => {
            const offer: PurchaselySubscriptionOffer = {
                subscriptionId: 'sub-123',
                basePlanId: null,
                offerToken: null,
                offerId: null,
            }

            expect(offer.basePlanId).toBeNull()
        })
    })
})

describe('Purchasely Event Names', () => {
    it('should support all event name types', () => {
        const eventNames: Array<PurchaselyEvent['name']> = [
            'APP_INSTALLED',
            'APP_CONFIGURED',
            'APP_UPDATED',
            'APP_STARTED',
            'CANCELLATION_REASON_PUBLISHED',
            'IN_APP_PURCHASING',
            'IN_APP_PURCHASED',
            'IN_APP_RESTORED',
            'IN_APP_DEFERRED',
            'IN_APP_PURCHASE_FAILED',
            'IN_APP_NOT_AVAILABLE',
            'PURCHASE_CANCELLED_BY_APP',
            'CAROUSEL_SLIDE_SWIPED',
            'DEEPLINK_OPENED',
            'LINK_OPENED',
            'LOGIN_TAPPED',
            'PLAN_SELECTED',
            'OPTIONS_SELECTED',
            'OPTIONS_VALIDATED',
            'PRESENTATION_VIEWED',
            'PRESENTATION_OPENED',
            'PRESENTATION_SELECTED',
            'PRESENTATION_LOADED',
            'PRESENTATION_CLOSED',
            'PROMO_CODE_TAPPED',
            'PURCHASE_CANCELLED',
            'PURCHASE_TAPPED',
            'RESTORE_TAPPED',
            'RECEIPT_CREATED',
            'RECEIPT_VALIDATED',
            'RECEIPT_FAILED',
            'RESTORE_STARTED',
            'RESTORE_SUCCEEDED',
            'RESTORE_FAILED',
            'SUBSCRIPTIONS_LIST_VIEWED',
            'SUBSCRIPTION_DETAILS_VIEWED',
            'SUBSCRIPTION_CANCEL_TAPPED',
            'SUBSCRIPTION_PLAN_TAPPED',
            'SUBSCRIPTIONS_TRANSFERRED',
            'USER_LOGGED_IN',
            'USER_LOGGED_OUT',
            'SUBSCRIPTION_CONTENT_USED',
        ]

        expect(eventNames).toHaveLength(42)
        eventNames.forEach(name => {
            expect(typeof name).toBe('string')
        })
    })
})
