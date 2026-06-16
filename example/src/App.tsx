import React, { useEffect } from 'react'
import { NavigationContainer } from '@react-navigation/native'
import { createNativeStackNavigator } from '@react-navigation/native-stack'
import { HomeScreen } from './Home.tsx'
import Purchasely, {
    DynamicOffering,
    InterceptResult,
    PLYDataProcessingLegalBasis,
    PLYDataProcessingPurpose,
    PresentationBuilder,
    PurchaselyUserAttribute,
    removeAllActionInterceptors,
} from 'react-native-purchasely'
import { PaywallScreen } from './Paywall.tsx'
import { PaywallPreloadedScreen } from './PaywallPreloaded.tsx'

const Stack = createNativeStackNavigator()

function App(): React.JSX.Element {
    async function setupPurchasely() {
        var configured = false
        try {
            // chained builder — the only supported way to start the SDK.
            // `allowDeeplink(true)` replaces the legacy `readyToOpenDeeplink`.
            configured = await Purchasely.builder(
                'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d'
            )
                .appUserId('test-user-id') // if you know your user id
                .runningMode('full') // to set mode manually
                .logLevel('debug') // to force log level for debug
                .allowDeeplink(true) // safe to launch purchase flow from deeplinks
                .allowCampaigns(true)
                .storekitVersion('storeKit2') // iOS: 'storeKit2' or 'storeKit1'
                .stores(['google']) // Android stores
                .start()
        } catch (e) {
            console.log('Purchasely SDK configuration error:', e)
        }

        if (!configured) {
            console.error('Purchasely SDK initialization failed.')
        } else {
            console.info('Purchasely SDK initialized successfully.')
        }

        // logout the user
        Purchasely.userLogout()

        //force your language
        Purchasely.setLanguage('en')

        // check that the user is anonymous
        await Purchasely.isAnonymous().then((isAnonymous) => {
            console.log('Is anonymous ? ' + isAnonymous)
        })

        // login the user
        Purchasely.userLogin('test-user')

        // check that the user is not anonymous anymore
        await Purchasely.isAnonymous().then((isAnonymous) => {
            console.log('User still anonymous ? ' + isAnonymous)
        })

        // Fetch the product with the identifier 'PURCHASELY_PLUS'
        const product = await Purchasely.productWithIdentifier(
            'PURCHASELY_PLUS'
        )
        console.log('Product', product)

        // Fetch the plan with the identifier 'PURCHASELY_PLUS_YEARLY'
        const plan = await Purchasely.planWithIdentifier(
            'PURCHASELY_PLUS_YEARLY'
        )
        console.log('Plan', plan)

        // Check whether the user is eligible for the intro offer 'PURCHASELY_PLUS_YEARLY'
        await Purchasely.isEligibleForIntroOffer('PURCHASELY_PLUS_YEARLY').then(
            (isEligible: boolean) => {
                console.log('Is eligible for intro offer ? ' + isEligible)
            }
        )

        // Fetch user's active subscriptions
        const subscriptions = await Purchasely.userSubscriptions()
        if(subscriptions.length > 0) {
            console.log('\t- cancelled date:', subscriptions[0].cancelledDate);
            console.log('\t- next renewal date:', subscriptions[0].nextRenewalDate);
            console.log('\t- subscription source:', subscriptions[0].subscriptionSource);
            console.log('\t- productId:', subscriptions[0].plan.productId);
            console.log('\t- vendorId:', subscriptions[0].plan.vendorId);
            console.log('\t- endorId:', subscriptions[0].plan.vendorId);
            console.log('\t- amount:', subscriptions[0].plan.amount);
            console.log('\t- period:', subscriptions[0].plan.period);
            console.log('\t- price:', subscriptions[0].plan.price);
            console.log('\t- localizedAmount:', subscriptions[0].plan.localizedAmount);
            console.log('\t- type:', subscriptions[0].plan.type);
            console.log('\t- hasFreeTrial:', subscriptions[0].plan.hasFreeTrial);
          }

        // Fetch user's expired subscriptions
        const expiredSubscriptions = await Purchasely.userSubscriptionsHistory()
        console.log(
            'Expired Subscriptions:',
            expiredSubscriptions.length,
            'subscriptions'
        )

        if (expiredSubscriptions.length > 0) {
            console.log(
                '\t- cancelled date:',
                expiredSubscriptions[0].cancelledDate
            )
            console.log(
                '\t- subscription source:',
                expiredSubscriptions[0].subscriptionSource
            )
            console.log(
                '\t- productId:',
                expiredSubscriptions[0].plan.productId
            )
            console.log('\t- vendorId:', expiredSubscriptions[0].plan.vendorId)
            console.log('\t- endorId:', expiredSubscriptions[0].plan.vendorId)
            console.log('\t- amount:', expiredSubscriptions[0].plan.amount)
            console.log('\t- period:', expiredSubscriptions[0].plan.period)
            console.log(
                '\t- localizedAmount:',
                expiredSubscriptions[0].plan.localizedAmount
            )
            console.log('\t- type:', expiredSubscriptions[0].plan.type)
            console.log(
                '\t- hasFreeTrial:',
                expiredSubscriptions[0].plan.hasFreeTrial
            )
        }

        Purchasely.addUserAttributeSetListener(
            (attribute: PurchaselyUserAttribute) => {
                console.log('Attribute set:', attribute)
            }
        )

        Purchasely.addUserAttributeRemovedListener((attribute) => {
            console.log('Attribute removed:', attribute)
        })

        //Set an attribute for each type
        Purchasely.setUserAttributeWithString('stringKey', 'StringValue', PLYDataProcessingLegalBasis.OPTIONAL)
        Purchasely.setUserAttributeWithNumber('intKey', 3, PLYDataProcessingLegalBasis.ESSENTIAL)
        Purchasely.setUserAttributeWithNumber('floatKey', 1.2, PLYDataProcessingLegalBasis.ESSENTIAL)
        Purchasely.setUserAttributeWithBoolean('booleanKey', true, PLYDataProcessingLegalBasis.ESSENTIAL)
        Purchasely.setUserAttributeWithDate('dateKey', new Date(), PLYDataProcessingLegalBasis.ESSENTIAL)

        Purchasely.setUserAttributeWithStringArray('stringArrayKey', [
            'StringValue',
            'Test',
        ], PLYDataProcessingLegalBasis.ESSENTIAL)
        Purchasely.setUserAttributeWithNumberArray('intArrayKey', [3, 42])
        Purchasely.setUserAttributeWithNumberArray(
            'floatArrayKey',
            [1.2, 23.23]
        , PLYDataProcessingLegalBasis.OPTIONAL)
        Purchasely.setUserAttributeWithBooleanArray('booleanArrayKey', [
            true,
            false,
            true,
        ])

        Purchasely.incrementUserAttribute({ key: 'sessions', value: 1 })
        Purchasely.incrementUserAttribute({ key: 'sessions' })
        Purchasely.incrementUserAttribute({ key: 'sessions', value: null })
        Purchasely.decrementUserAttribute({ key: 'sessions' })

        Purchasely.incrementUserAttribute({ key: 'app_views', value: 8.4 }) // will be rounded to 8

        //get all attributes
        const attributes = await Purchasely.userAttributes()
        console.log('Attributes:', attributes)

        //retrive a date attribute
        const dateAttribute = await Purchasely.userAttribute('dateKey')
        console.log('dateKey =', new Date(dateAttribute).getFullYear())

        //remove an attribute
        Purchasely.clearUserAttribute('dateKey')
        console.log('dateKey =', await Purchasely.userAttribute('dateKey'))

        //remove all attributes
        Purchasely.clearUserAttributes()

        //remove all Purchasley built-in attributes
        Purchasely.clearBuiltInAttributes()

        //set a dynamic offering
        const p1yOffer = await Purchasely.setDynamicOffering({
            reference: 'p1yOffer',
            planVendorId: 'PURCHASELY_PLUS_YEARLY',
            offerVendorId: 'Winback',
        })
        console.log('Dynamic offering p1yOffer:', p1yOffer)

        const p1m = await Purchasely.setDynamicOffering({
            reference: 'p1m',
            planVendorId: 'PURCHASELY_PLUS_MONTHLY',
            offerVendorId: 'NON_EXISTING_OFFER',
        })
        console.log('Dynamic offering p1mError:', p1m)

        const p1y = await Purchasely.setDynamicOffering({
            reference: 'p1y',
            planVendorId: 'PURCHASELY_PLUS_YEARLY'
        })
        console.log('Dynamic offering p1y:', p1y)

        //get dynamic offerings
        const offerings: DynamicOffering[] = await Purchasely.getDynamicOfferings()
        console.log('Dynamic offerings:', offerings)

        //remove a dynamic offering
        Purchasely.removeDynamicOffering('p1yOffer')

        //clear all dynamic offerings
        Purchasely.clearDynamicOfferings()

        //Purchasely.revokeDataProcessingConsent([PLYDataProcessingPurpose.ALL_NON_ESSENTIALS])

        const offeringsEmpty: DynamicOffering[] = await Purchasely.getDynamicOfferings()
        console.log('Dynamic offerings:', offeringsEmpty)

        // Set paywall action interceptors. Each handler is typed by the
        // action kind and must return 'success' | 'failed' | 'notHandled'.
        // Returning 'notHandled' lets the SDK perform its default behavior;
        // 'success' tells the SDK the host app fully handled the action.

        // Navigate action — open the requested website yourself if needed.
        Purchasely.interceptAction('navigate', async (info, payload): Promise<InterceptResult> => {
            console.log('User wants to navigate', info, payload)
            if (payload?.kind === 'navigate') {
                console.log(
                    'User wants to navigate to website ' +
                        payload.title +
                        ' ' +
                        payload.url
                )
            }
            // Let the SDK open the URL with its default behavior.
            return 'notHandled'
        })

        // Login action — present your own login screen here. Returning
        // 'success' tells the SDK login is handled by the host app.
        Purchasely.interceptAction('login', async (info): Promise<InterceptResult> => {
            console.log('User wants to login', info)
            // Present your own screen for the user to log in, then return
            // 'success' once done — or 'notHandled' to keep the SDK default.
            return 'notHandled'
        })

        // Purchase action — intercept the purchase if you handle it yourself,
        // otherwise return 'notHandled' to let Purchasely run the purchase.
        Purchasely.interceptAction('purchase', async (info, payload): Promise<InterceptResult> => {
            console.log('User wants to purchase', info, payload)
            /**
             * To intercept the purchase, present your own screen and run your
             * own transaction, then return 'success' or 'failed'.
             * Returning 'notHandled' lets Purchasely run its default purchase
             * flow. To close the paywall programmatically afterwards, hold a
             * reference to the PresentationRequest and call `request.close()`.
             **/
            return 'notHandled'
        })

        // Set events listener
        /**
         * Purchasely devs only
         * It's possible that to make it work with this sample project you need to change the import in index.ts to the following:
         * import { NativeModules, NativeEventEmitter } from '../../react-native';
         */
        Purchasely.addEventListener((event) => {
            console.info('Event received:', event.name)
            //console.log(event.properties);
        })

        console.log('Add purchase listener')
        Purchasely.addPurchasedListener(() => {
            console.log('Purchase successful')
        })
    }

    // Preload a placement so its paywall is ready before the user reaches it.
    // The `preload()` resolves once the screen is loaded (no UI shown yet).
    const preloadOnboarding = async () => {
        try {
            const presentation = await PresentationBuilder.placement(
                'ONBOARDING'
            )
                .contentId(null)
                .build()
                .preload()
            console.info('[Purchasely] preloaded', presentation.screenId)
        } catch (e) {
            console.error(e)
        }
    }

    // -------------------------------------------------------------------------
    // presentation demo. Builds an ONBOARDING placement request, wires up
    // every lifecycle callback, then displays it. `display()` resolves at
    // DISMISS with a 5-field `PresentationOutcome`.
    //
    // To opt in, uncomment the `presentOnboarding()` call inside the
    // `useEffect` below.
    // -------------------------------------------------------------------------
    async function presentOnboarding() {
        // Build, present and react to lifecycle callbacks.
        const request = PresentationBuilder.placement('ONBOARDING')
            .contentId('content_123')
            .onLoaded((presentation) => {
                console.info('[Purchasely] loaded', presentation.screenId)
            })
            .onPresented((presentation, error) => {
                if (error) {
                    console.error('[Purchasely] presented error', error)
                    return
                }
                console.info('[Purchasely] presented', presentation?.screenId)
            })
            .onCloseRequested(() => {
                console.info('[Purchasely] close requested by host')
            })
            .onDismissed((outcome) => {
                console.info(
                    '[Purchasely] dismissed',
                    'purchaseResult=', outcome.purchaseResult,
                    'plan=', outcome.plan?.vendorId,
                    'closeReason=', outcome.closeReason,
                    'error=', outcome.error?.message
                )
            })
            .build()

        const outcome = await request.display({ type: 'fullScreen' })
        console.info('[Purchasely] display() resolved with outcome', outcome)

        // Detach every interceptor previously registered.
        removeAllActionInterceptors()
    }

    useEffect(() => {
        setupPurchasely()
        preloadOnboarding()
        // Uncomment to display the ONBOARDING paywall through the presentation pipeline
        // once the SDK has been started by `setupPurchasely()` above.
        // presentOnboarding()
    }, [])

    return (
        <NavigationContainer>
            <Stack.Navigator screenOptions={{ headerShown: false }}>
                <Stack.Screen
                    name="Home"
                    component={HomeScreen}
                    options={{ title: 'Welcome' }}
                />
                <Stack.Screen name="Paywall" component={PaywallScreen} />
                <Stack.Screen
                    name="PaywallPreloaded"
                    component={PaywallPreloadedScreen}
                />
            </Stack.Navigator>
        </NavigationContainer>
    )
}

export default App
