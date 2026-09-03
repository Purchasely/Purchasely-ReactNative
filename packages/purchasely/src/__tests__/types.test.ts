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
    PLYPlan,
    PLYProduct,
    PLYSubscription,
    PLYPromotionalOfferSignature,
    PLYUserAttribute,
    PLYEvent,
    PLYEventProperties,
    PLYPresentationPlan,
    PLYPresentationMetadata,
    PLYPromoOffer,
    PLYSubscriptionOffer,
    PLYCommitmentInfo,
    PLYCommitmentProgress,
    PLYBillingPlanType,
    PLYEventPropertyRedemption,
    PLYWebRedemptionResult,
} from '../types'
import type { PLYPurchasePayload } from '../presentationTypes'

import {
    PlanType,
    SubscriptionSource,
    PLYUserAttributeSource,
    PLYUserAttributeType,
    PLYWebCheckoutProvider,
    PLYDataProcessingLegalBasis,
} from '../enums'
import { normalizePlan, normalizePlanType } from '../presentationTypes'

describe('Purchasely Types', () => {
    describe('PLYPlan', () => {
        it('should accept valid plan object', () => {
            const plan: PLYPlan = {
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
                hasOfferPrice: false,
                offerPrice: '',
                offerAmount: 0,
                offerDuration: '',
                offerPeriod: '',
            }

            expect(plan.vendorId).toBe('monthly-plan')
            expect(plan.type).toBe(PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION)
            expect(plan.hasIntroductoryPrice).toBe(true)
        })

        it('should handle consumable plan type', () => {
            const plan: PLYPlan = {
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
                hasOfferPrice: false,
                offerPrice: '',
                offerAmount: 0,
                offerDuration: '',
                offerPeriod: '',
            }

            expect(plan.type).toBe(PlanType.PLAN_TYPE_CONSUMABLE)
        })
    })

    describe('PLYProduct', () => {
        it('should accept valid product object', () => {
            const product: PLYProduct = {
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
                        hasOfferPrice: false,
                        offerPrice: '',
                        offerAmount: 0,
                        offerDuration: '',
                        offerPeriod: '',
                    },
                ],
            }

            expect(product.name).toBe('Premium Subscription')
            expect(product.plans).toHaveLength(1)
            expect(product.plans?.[0]?.hasFreeTrial).toBe(true)
        })

        it('should handle product with empty plans array', () => {
            const product: PLYProduct = {
                name: 'Empty Product',
                vendorId: 'empty-product',
                plans: [],
            }

            expect(product.plans).toHaveLength(0)
        })
    })

    describe('PLYSubscription', () => {
        it('should accept valid subscription object', () => {
            const subscription: PLYSubscription = {
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
                    hasOfferPrice: false,
                    offerPrice: '',
                    offerAmount: 0,
                    offerDuration: '',
                    offerPeriod: '',
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

        // [PAR-24] cumulatedRevenuesInUSD / subscriptionDurationIn{Days,Weeks,Months}
        // were commented out of the type despite Android's native
        // PLYSubscription.toMap() providing them. Reactivated as optional
        // (Android-only; iOS's PLYSubscription+Hybrid.m never emits them).
        it('should accept the Android-only revenue/duration fields when present', () => {
            const subscription: PLYSubscription = {
                purchaseToken: 'token-123',
                subscriptionSource: SubscriptionSource.GOOGLE_PLAY_STORE,
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
                    hasOfferPrice: false,
                    offerPrice: '',
                    offerAmount: 0,
                    offerDuration: '',
                    offerPeriod: '',
                },
                product: {
                    name: 'Premium',
                    vendorId: 'premium-product',
                    plans: [],
                },
                cumulatedRevenuesInUSD: 59.94,
                subscriptionDurationInDays: 180,
                subscriptionDurationInWeeks: 25,
                subscriptionDurationInMonths: 6,
            }

            expect(subscription.cumulatedRevenuesInUSD).toBe(59.94)
            expect(subscription.subscriptionDurationInDays).toBe(180)
            expect(subscription.subscriptionDurationInWeeks).toBe(25)
            expect(subscription.subscriptionDurationInMonths).toBe(6)
        })

        it('should accept a subscription omitting the Android-only fields (iOS shape)', () => {
            const subscription: PLYSubscription = {
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
                    hasOfferPrice: false,
                    offerPrice: '',
                    offerAmount: 0,
                    offerDuration: '',
                    offerPeriod: '',
                },
                product: {
                    name: 'Premium',
                    vendorId: 'premium-product',
                    plans: [],
                },
            }

            expect(subscription.cumulatedRevenuesInUSD).toBeUndefined()
        })
    })

    // Apple-only (iOS 26.4+) "monthly subscription with 12-month commitment".
    // Structured data on the plan / subscription — distinct from the
    // `billing_plan_type` / `commitment` / `commitment_progress` *event* strings
    // in PLYEventProperties.
    describe('PLYCommitmentInfo (Apple-only)', () => {
        const commitmentInfo: PLYCommitmentInfo[] = [
            {
                billingPlanType: 'monthly',
                billingPrice: 9.99,
                billingPeriod: 'P1M',
                totalPrice: 119.88,
                totalPeriod: 'P1Y',
                totalDuration: 12,
            },
        ]

        const committedPlan: PLYPlan = {
            vendorId: 'monthly-12mo',
            productId: 'product-123',
            name: 'Monthly (12-month commitment)',
            type: PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION,
            amount: 9.99,
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
            hasOfferPrice: false,
            offerPrice: '',
            offerAmount: 0,
            offerDuration: '',
            offerPeriod: '',
            commitmentInfo,
        }

        it('exposes structured commitment info on a plan', () => {
            expect(committedPlan.commitmentInfo).toHaveLength(1)
            expect(committedPlan.commitmentInfo?.[0]?.billingPlanType).toBe('monthly')
            expect(committedPlan.commitmentInfo?.[0]?.billingPrice).toBe(9.99)
            expect(committedPlan.commitmentInfo?.[0]?.totalPrice).toBe(119.88)
            expect(committedPlan.commitmentInfo?.[0]?.totalPeriod).toBe('P1Y')
            expect(committedPlan.commitmentInfo?.[0]?.totalDuration).toBe(12)
        })

        it('is optional (absent on Android and non-committed Apple plans)', () => {
            const plainPlan: PLYPlan = {
                ...committedPlan,
                commitmentInfo: undefined,
            }
            expect(plainPlan.commitmentInfo).toBeUndefined()
        })

        it('accepts every billing plan type', () => {
            const types: PLYBillingPlanType[] = [
                'unspecified',
                'upFront',
                'monthly',
            ]
            expect(types).toHaveLength(3)
        })

        it('carries commitmentInfo on the interceptAction purchase payload plan', () => {
            const payload: PLYPurchasePayload = {
                kind: 'purchase',
                plan: committedPlan,
            }
            expect(payload.plan.commitmentInfo?.[0]?.totalDuration).toBe(12)
        })
    })

    describe('PLYCommitmentProgress (Apple-only)', () => {
        const baseSubscription: PLYSubscription = {
            purchaseToken: 'token-123',
            subscriptionSource: SubscriptionSource.APPLE_APP_STORE,
            nextRenewalDate: '2026-08-20T12:00:00Z',
            cancelledDate: '',
            plan: {
                vendorId: 'monthly-12mo',
                productId: 'premium-product',
                name: 'Monthly',
                type: PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION,
                amount: 9.99,
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
                hasOfferPrice: false,
                offerPrice: '',
                offerAmount: 0,
                offerDuration: '',
                offerPeriod: '',
            },
            product: {
                name: 'Premium',
                vendorId: 'premium-product',
                plans: [],
            },
        }

        it('exposes commitment progress on a subscription', () => {
            const commitmentProgress: PLYCommitmentProgress = {
                billingPeriodNumber: 3,
                totalBillingPeriods: 12,
                commitmentExpiresDate: '2026-07-20T12:00:00Z',
                commitmentPrice: 9.99,
            }
            const subscription: PLYSubscription = {
                ...baseSubscription,
                commitmentProgress,
            }
            expect(subscription.commitmentProgress?.billingPeriodNumber).toBe(3)
            expect(subscription.commitmentProgress?.totalBillingPeriods).toBe(12)
            expect(subscription.commitmentProgress?.commitmentExpiresDate).toBe(
                '2026-07-20T12:00:00Z'
            )
            expect(subscription.commitmentProgress?.commitmentPrice).toBe(9.99)
        })

        it('is optional / nullable (absent on Android and non-committed subs)', () => {
            expect(baseSubscription.commitmentProgress).toBeUndefined()
            const nulled: PLYSubscription = {
                ...baseSubscription,
                commitmentProgress: null,
            }
            expect(nulled.commitmentProgress).toBeNull()
        })
    })

    describe('PLYPromotionalOfferSignature', () => {
        it('should accept valid signature object', () => {
            const signature: PLYPromotionalOfferSignature = {
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

    describe('PLYUserAttribute', () => {
        it('should accept user attribute with all fields', () => {
            const attr: PLYUserAttribute = {
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
            const attr: PLYUserAttribute = {
                key: 'counter',
                value: null,
                type: null,
                source: null,
            }

            expect(attr.value).toBeNull()
        })
    })

    describe('PLYEvent', () => {
        it('should accept valid event object', () => {
            const event: PLYEvent = {
                name: 'PURCHASE_TAPPED',
                properties: {
                    sdk_version: '5.7.3',
                    event_name: 'PURCHASE_TAPPED',
                    event_created_at_ms: 1705315200000,
                    event_created_at: '2024-01-15T12:00:00Z',
                    user_id: 'user-123',
                    displayed_presentation: 'pres-123',
                    selected_plan: 'monthly-plan',
                },
            }

            expect(event.name).toBe('PURCHASE_TAPPED')
            expect(event.properties.sdk_version).toBe('5.7.3')
        })

        it('should accept the extended event properties emitted by the native SDKs', () => {
            const properties: PLYEventProperties = {
                sdk_version: '5.7.3',
                event_name: 'PURCHASE_TAPPED',
                event_created_at_ms: 1705315200000,
                event_created_at: '2024-01-15T12:00:00Z',
                // Presentation & campaign context
                is_fallback_presentation: false,
                presentation_type: 'NORMAL',
                audience_id: 'audience-123',
                ab_test_id: 'ab-123',
                ab_test_variant_id: 'variant-a',
                content_id: 'content-123',
                campaign_id: 'campaign-123',
                flow_id: 'flow-123',
                step_id: 'step-123',
                flow_version: '2',
                flow_session_id: 'flow-session-123',
                from_action_id: 'action-123',
                from_step_id: 'step-122',
                // Display, timing & session metrics
                display_mode: 'fullscreen',
                display_method: 'present',
                orientation: 'portrait',
                paywall_request_duration_in_ms: 120,
                paywall_display_time_in_ms: 340,
                paywall_rendering_time_in_ms: 80,
                screen_duration: 1500,
                session_id: 'session-123',
                session_duration: 4200,
                session_count: 7,
                app_installed_at: '2024-01-01T00:00:00Z',
                app_installed_at_ms: 1704067200000,
                // Offer & plan details
                promo_offer: 'promo-123',
                eligible_to_intro_offer: true,
                eligible_to_promo_offer: false,
                billing_plan_type: 'recurring',
                commitment: 'yearly',
                storekit_version: 'storeKit2',
                // SDK lifecycle
                is_sdk_started: true,
                sdk_start_duration_in_ms: 250,
                // Web checkout
                web_checkout_provider: PLYWebCheckoutProvider.STRIPE,
                web_checkout_url: 'https://checkout.example.com/session',
                client_reference_id: 'client-ref-123',
                stripe_checkout_session_id: 'cs_test_123',
                stripe_purchase_id: 'pi_test_123',
            }

            expect(properties.flow_id).toBe('flow-123')
            expect(properties.eligible_to_intro_offer).toBe(true)
            expect(properties.web_checkout_provider).toBe(
                PLYWebCheckoutProvider.STRIPE
            )
            expect(properties.stripe_purchase_id).toBe('pi_test_123')
        })

        // Wire shape verified against iOS `RedemptionOutcome.swift` and the
        // Android `RedemptionProperties` serializer, which the Android
        // `PLYEventPropertiesRedemptionJsonRegressionTest` pins byte for byte.
        it('should accept the REDEMPTION_CONSUMED payload', () => {
            const event: PLYEvent = {
                name: 'REDEMPTION_CONSUMED',
                properties: {
                    sdk_version: '6.1.0',
                    event_name: 'REDEMPTION_CONSUMED',
                    event_created_at_ms: 1705315200000,
                    event_created_at: '2024-01-15T12:00:00Z',
                    redemption: {
                        token: 'redemption-token-123',
                        receipt: {
                            id: 'receipt-123',
                            validation_status: 'COMPLETED',
                        },
                        subscriptions: [
                            {
                                public_id: 'subs-123',
                                plan_id: 'plan-123',
                                store_type: 'APPLE_APP_STORE',
                                subscription_status: 'ACTIVE',
                                environment: 'PROD',
                            },
                        ],
                        purchase_context: {
                            version: 1,
                            source: 'web',
                            sandbox: false,
                            replay: false,
                            built_in_attributes: [
                                { key: 'firebase_app_instance_id', type: 'string', value: 'abc' },
                            ],
                            custom_attributes: [{ key: 'plan', type: 'string', value: 'gold' }],
                        },
                    },
                },
            }

            expect(event.properties.redemption?.receipt?.validation_status).toBe('COMPLETED')
            expect(event.properties.redemption?.subscriptions).toHaveLength(1)
            expect(event.properties.redemption?.purchase_context?.replay).toBe(false)
        })

        it('should accept the REDEMPTION_FAILED payload, with error_message at the top level', () => {
            const event: PLYEvent = {
                name: 'REDEMPTION_FAILED',
                properties: {
                    sdk_version: '6.1.0',
                    event_name: 'REDEMPTION_FAILED',
                    event_created_at_ms: 1705315200000,
                    event_created_at: '2024-01-15T12:00:00Z',
                    redemption: {
                        token: 'redemption-token-123',
                        error_code: 'EXPIRED_REDEMPTION_TOKEN',
                    },
                    error_message: 'Redemption link has expired.',
                },
            }

            expect(event.properties.redemption?.error_code).toBe('EXPIRED_REDEMPTION_TOKEN')
            expect(event.properties.error_message).toBe('Redemption link has expired.')
        })

        // A transport or parsing failure never reaches the server, so it
        // carries no code.
        it('should accept a REDEMPTION_FAILED payload without an error code', () => {
            const redemption: PLYEventPropertyRedemption = {
                token: 'redemption-token-123',
            }

            expect(redemption.error_code).toBeUndefined()
        })
    })

    describe('PLYWebRedemptionResult', () => {
        it('should accept a success that granted a subscription', () => {
            const result: PLYWebRedemptionResult = {
                isSuccess: true,
                context: {
                    subscription: {
                        purchaseToken: 'token-123',
                        subscriptionSource: SubscriptionSource.APPLE_APP_STORE,
                        nextRenewalDate: '2024-02-15T12:00:00Z',
                        cancelledDate: '',
                        plan: { vendorId: 'plan-123', name: 'Gold', type: PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION },
                        product: { name: 'Gold', vendorId: 'product-123', plans: [] },
                    },
                },
                replay: false,
                errorCode: null,
                errorMessage: null,
            }

            expect(result.context?.subscription?.purchaseToken).toBe('token-123')
        })

        // Both levels are nullable on both platforms: a 200 can describe
        // nothing, and a present context can hold no subscription.
        it('should accept a success with a null context', () => {
            const result: PLYWebRedemptionResult = {
                isSuccess: true,
                context: null,
                replay: true,
                errorCode: null,
                errorMessage: null,
            }

            expect(result.context).toBeNull()
            expect(result.replay).toBe(true)
        })

        it('should accept a success whose context holds a null subscription', () => {
            const result: PLYWebRedemptionResult = {
                isSuccess: true,
                context: { subscription: null },
                replay: false,
                errorCode: null,
                errorMessage: null,
            }

            expect(result.context?.subscription).toBeNull()
        })

        it('should accept a failure, with replay false and no context', () => {
            const result: PLYWebRedemptionResult = {
                isSuccess: false,
                context: null,
                replay: false,
                errorCode: 'INVALID_REDEMPTION_TOKEN',
                errorMessage: 'Redemption link is not valid.',
            }

            expect(result.errorCode).toBe('INVALID_REDEMPTION_TOKEN')
            expect(result.replay).toBe(false)
        })

        // A transport failure never reaches the server, so it carries no code.
        it('should accept a failure with a null error code', () => {
            const result: PLYWebRedemptionResult = {
                isSuccess: false,
                context: null,
                replay: false,
                errorCode: null,
                errorMessage: 'Redemption could not be completed.',
            }

            expect(result.errorCode).toBeNull()
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

    describe('PLYPromoOffer', () => {
        it('should accept valid offer', () => {
            const offer: PLYPromoOffer = {
                vendorId: 'offer-123',
                storeOfferId: 'store-offer-123',
            }

            expect(offer.vendorId).toBe('offer-123')
        })

        it('should accept offer with null fields', () => {
            const offer: PLYPromoOffer = {
                vendorId: null,
                storeOfferId: null,
            }

            expect(offer.vendorId).toBeNull()
        })
    })

    describe('PLYSubscriptionOffer', () => {
        it('should accept valid subscription offer', () => {
            const offer: PLYSubscriptionOffer = {
                subscriptionId: 'sub-123',
                basePlanId: 'base-plan',
                offerToken: 'token-123',
                offerId: 'offer-123',
            }

            expect(offer.subscriptionId).toBe('sub-123')
        })

        it('should accept subscription offer with null optional fields', () => {
            const offer: PLYSubscriptionOffer = {
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
        const eventNames: Array<PLYEvent['name']> = [
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
            // New on both native platforms in 6.1.0 (Web2App redemption).
            'REDEMPTION_CONSUMED',
            'REDEMPTION_FAILED',
        ]

        expect(eventNames).toHaveLength(44)
        eventNames.forEach(name => {
            expect(typeof name).toBe('string')
        })
    })

    // [rc.4 hardening] Android's native SDK is expected to start emitting
    // plan.type as a DistributionType string (e.g. "RENEWING_SUBSCRIPTION")
    // instead of the numeric ordinal every platform emits today.
    describe('normalizePlanType / normalizePlan (rc.4 hardening)', () => {
        it('passes a numeric ordinal through unchanged', () => {
            expect(normalizePlanType(PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION)).toBe(
                PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION
            )
            expect(normalizePlanType(0)).toBe(0)
        })

        it('maps every known Android DistributionType string name to its ordinal', () => {
            expect(normalizePlanType('CONSUMABLE')).toBe(PlanType.PLAN_TYPE_CONSUMABLE)
            expect(normalizePlanType('NON_CONSUMABLE')).toBe(PlanType.PLAN_TYPE_NON_CONSUMABLE)
            expect(normalizePlanType('RENEWING_SUBSCRIPTION')).toBe(
                PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION
            )
            expect(normalizePlanType('NON_RENEWING_SUBSCRIPTION')).toBe(
                PlanType.PLAN_TYPE_NON_RENEWING_SUBSCRIPTION
            )
            expect(normalizePlanType('UNKNOWN')).toBe(PlanType.PLAN_TYPE_UNKNOWN)
        })

        it('returns null for null/undefined/unrecognized input', () => {
            expect(normalizePlanType(null)).toBeNull()
            expect(normalizePlanType(undefined)).toBeNull()
            expect(normalizePlanType('NOT_A_REAL_TYPE')).toBeNull()
        })

        it('normalizePlan rewrites only the type field of a raw plan payload', () => {
            const raw = { vendorId: 'monthly', type: 'RENEWING_SUBSCRIPTION', hasFreeTrial: false }
            expect(normalizePlan(raw)).toEqual({
                vendorId: 'monthly',
                type: PlanType.PLAN_TYPE_AUTO_RENEWING_SUBSCRIPTION,
                hasFreeTrial: false,
            })
        })

        it('normalizePlan leaves an already-numeric type untouched', () => {
            const raw = { vendorId: 'monthly', type: PlanType.PLAN_TYPE_CONSUMABLE }
            expect(normalizePlan(raw)).toEqual(raw)
        })

        it('normalizes unknown string and inherited-key types to PLAN_TYPE_UNKNOWN', () => {
            expect(normalizePlan({ vendorId: 'monthly', type: 'FUTURE_DISTRIBUTION_TYPE' }))
                .toEqual({ vendorId: 'monthly', type: PlanType.PLAN_TYPE_UNKNOWN })
            expect(normalizePlan({ vendorId: 'monthly', type: 'constructor' }))
                .toEqual({ vendorId: 'monthly', type: PlanType.PLAN_TYPE_UNKNOWN })
        })

        it('normalizePlan passes through non-plan-shaped values unchanged', () => {
            expect(normalizePlan(null)).toBeNull()
            expect(normalizePlan(undefined)).toBeUndefined()
            expect(normalizePlan({ vendorId: 'monthly' })).toEqual({ vendorId: 'monthly' })
        })
    })
})
