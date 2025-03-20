import React, { useEffect } from 'react'
import { NavigationContainer } from '@react-navigation/native'
import { createNativeStackNavigator } from '@react-navigation/native-stack'
import { HomeScreen } from './Home.tsx'
import Purchasely, {
    LogLevels,
    PLYPaywallAction,
    PurchaselyUserAttribute,
    RunningMode,
} from 'react-native-purchasely'
import { PaywallScreen } from './Paywall.tsx'

const Stack = createNativeStackNavigator()

function App(): React.JSX.Element {
    async function setupPurchasely() {
        var configured = false
        try {
            // ApiKey and StoreKit1 attributes are mandatory
            configured = await Purchasely.start({
                apiKey: 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d',
                storeKit1: false, // false to use StoreKit 2 and true to use StoreKit 1
                logLevel: LogLevels.DEBUG, // to force log level for debug
                userId: 'test-user', // if you know your user id
                runningMode: RunningMode.FULL, // to set mode manually
            })
        } catch (e) {
            console.log('Purchasely SDK configuration error:', e)
        }

        // fetchPresentation()

        if (!configured) {
            console.error('Purchasely SDK initialization failed.')
        } else {
            console.info('Purchasely SDK initialized successfully.')
        }

        // logout the user
        Purchasely.userLogout()

        //indicate to sdk it is safe to launch purchase flow
        Purchasely.readyToOpenDeeplink(true)

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
        Purchasely.setUserAttributeWithString('stringKey', 'StringValue')
        Purchasely.setUserAttributeWithNumber('intKey', 3)
        Purchasely.setUserAttributeWithNumber('floatKey', 1.2)
        Purchasely.setUserAttributeWithBoolean('booleanKey', true)
        Purchasely.setUserAttributeWithDate('dateKey', new Date())

        Purchasely.setUserAttributeWithStringArray('stringArrayKey', [
            'StringValue',
            'Test',
        ])
        Purchasely.setUserAttributeWithNumberArray('intArrayKey', [3, 42])
        Purchasely.setUserAttributeWithNumberArray(
            'floatArrayKey',
            [1.2, 23.23]
        )
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

        // Set paywall action interceptor callback
        Purchasely.setPaywallActionInterceptorCallback((result) => {
            console.log('Received action from paywall')
            console.log(result.info)

            switch (result.action) {
                case PLYPaywallAction.NAVIGATE:
                    console.log(
                        'User wants to navigate to website ' +
                            result.parameters.title +
                            ' ' +
                            result.parameters.url
                    )
                    Purchasely.onProcessAction(true)
                    break
                case PLYPaywallAction.LOGIN:
                    console.log('User wants to login')
                    //Present your own screen for user to log in
                    Purchasely.hidePresentation()
                    // Call this method to display Purchaely paywall
                    // Purchasely.showPresentation()
                    // Call this method to update Purchasely Paywall
                    // Purchasely.onProcessAction(true);
                    break
                case PLYPaywallAction.PURCHASE:
                    console.log('User wants to purchase')
                    Purchasely.onProcessAction(true)
                    //Purchasely.hidePresentation();

                    /**
                     * If you want to intercept it, hide presentation and display your screen
                     * then call onProcessAction() to continue or stop purchasely purchase action like this
                     *
                     * First hide presentation to display your own screen
                     * Purchasely.hidePresentation()
                     *
                     * Call this method to display Purchasely paywall
                     * Purchasely.showPresentation()
                     *
                     * Call this method to update Purchasely Paywall
                     * Purchasely.onProcessAction(true|false); // true to continue, false to stop
                     *
                     * Purchasely.closePresentation(); //when you want to close the paywall (after purchase for example)
                     *
                     **/
                    break
                default:
                    Purchasely.onProcessAction(true)
            }
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

    const fetchPresentation = async () => {
        try {
            await Purchasely.fetchPresentation({
                placementId: 'ONBOARDING',
                contentId: null,
            })
        } catch (e) {
            console.error(e)
        }
    }

    useEffect(() => {
        setupPurchasely()
        fetchPresentation()
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
            </Stack.Navigator>
        </NavigationContainer>
    )
}

export default App
