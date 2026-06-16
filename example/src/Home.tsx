import {
    SafeAreaView,
    ScrollView,
    StyleSheet,
    Text,
    TouchableOpacity,
    useColorScheme,
    View,
} from 'react-native'
import { NativeStackScreenProps } from '@react-navigation/native-stack'
import { Colors } from 'react-native/Libraries/NewAppScreen'
import Purchasely, {
    PLYPresentationType,
    PresentationBuilder,
    PresentationRequest,
} from 'react-native-purchasely'

import DeviceInfo from 'react-native-device-info'
import { useRef } from 'react'

export const HomeScreen: React.FC<NativeStackScreenProps<any>> = ({
    navigation,
}) => {
    const isDarkMode = useColorScheme() === 'dark'
    // Holds the most recently displayed presentation request so it can be closed or
    // navigated back programmatically (replaces the v5 show/hide/close calls).
    const currentRequest = useRef<PresentationRequest | null>(null)

    const backgroundStyle = {
        backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
    }

    // Boutons d'exemples
    const buttons = [
        { title: 'Display Presentation', onPress: () => onPressPresentation() },
        { title: 'Preload Presentation', onPress: () => onPressPreload() },
        { title: 'Display Nested View', onPress: () => onPressNestedView() },
        {
            title: 'Close Presentation',
            onPress: () => onPressClosePresentation(),
        },
        { title: 'Back', onPress: () => onPressBack() },
        { title: 'Purchase', onPress: () => onPressPurchase() },
        {
            title: 'Purchase With Promotional Offer',
            onPress: () => onPressPurchaseWithPromotionalOffer(),
        },
        {
            title: 'Sign Promotional Offer',
            onPress: () => onPressSignPromotionalOffer(),
        },
        {
            title: 'Display Subscriptions',
            onPress: () => onPressSubscriptions(),
        },
        { title: 'Restore', onPress: () => onPressRestore() },
        { title: 'Silent Restore', onPress: () => onPressSilentRestore() },
        { title: 'Synchronize', onPress: () => onPressSynchronize() },
    ]

    const onPressPresentation = async () => {
        try {
            // build a request for the placement, then display it.
            // `display()` resolves at DISMISS with a PresentationOutcome.
            const request = PresentationBuilder.placement('premium_support')
                .backgroundColor('#FFFFFFFF')
                .build()
            currentRequest.current = request

            const outcome = await request.display({ type: 'fullScreen' })

            console.log('Purchase result is ' + outcome.purchaseResult)

            switch (outcome.purchaseResult) {
                case 'purchased':
                case 'restored':
                    if (outcome.plan != null) {
                        console.log('User purchased ' + outcome.plan.name)
                    }
                    break
                case 'cancelled':
                    break
            }
        } catch (e) {
            console.error(e)
        }
    }

    const onPressPreload = async () => {
        try {
            // preload a placement without showing any UI yet. Resolves once
            // the screen is loaded. Inspect the resolved Presentation to decide
            // whether to display a Purchasely paywall or your own screen.
            const presentation = await PresentationBuilder.placement('FLOW')
                .contentId(null)
                .build()
                .preload()

            console.log(presentation.placementId)
            console.log('Type = ' + presentation.type)
            console.log(
                'Plans = ' + JSON.stringify(presentation.plans, null, 2)
            )

            if (presentation.type === PLYPresentationType.DEACTIVATED) {
                // No paywall to display
                return
            }

            if (presentation.type === PLYPresentationType.CLIENT) {
                // Display my own paywall
                console.log(
                    'metadata: ' +
                        JSON.stringify(presentation.metadata, null, 2)
                )
                return
            }

            // Display the preloaded Purchasely paywall.
            const request = PresentationBuilder.placement('FLOW')
                .contentId(null)
                .build()
            currentRequest.current = request

            const outcome = await request.display({ type: 'fullScreen' })

            console.log('---- Paywall Closed ----')
            console.log('Purchase result is ' + outcome.purchaseResult)

            switch (outcome.purchaseResult) {
                case 'purchased':
                case 'restored':
                    if (outcome.plan != null) {
                        console.log('User purchased ' + outcome.plan.name)
                    }
                    break
                case 'cancelled':
                    console.log('User cancelled')
                    break
            }
        } catch (e) {
            console.error(e)
        }
    }

    const onPressNestedView = () => {
        // The embedded PLYPresentationView is driven by a placement id.
        navigation.navigate('Paywall', {
            placementId: 'nested',
        })
    }

    const onPressClosePresentation = () => {
        // close the currently displayed request programmatically.
        currentRequest.current?.close()
    }

    const onPressBack = () => {
        // navigate back inside a multi-step (Flow) presentation.
        currentRequest.current?.back()
    }

    const onPressPurchase = async () => {
        try {
            const plan = await Purchasely.purchaseWithPlanVendorId({
                planVendorId: 'PURCHASELY_PLUS_MONTHLY',
                offerId: null,
                contentId: 'my_content_id',
            })
            console.log('Purchased ' + plan)
        } catch (e) {
            console.error(e)
        }
    }

    const onPressPurchaseWithPromotionalOffer = async () => {
        try {
            const plan = await Purchasely.purchaseWithPlanVendorId({
                planVendorId: 'PURCHASELY_PLUS_YEARLY',
                offerId: 'com.purchasely.plus.yearly.promo',
                contentId: 'my_content_id',
            })
            console.log('Purchased ' + plan)
        } catch (e) {
            console.error(e)
        }
    }

    const onPressSignPromotionalOffer = async () => {
        try {
            const signature = await Purchasely.signPromotionalOffer({
                storeProductId: 'com.purchasely.plus.yearly',
                storeOfferId: 'com.purchasely.plus.yearly.winback.test',
            })

            console.log('Signature timestamp: ' + signature.timestamp)
            console.log('Signature planVendorId: ' + signature.planVendorId)
            console.log('Signature identifier: ' + signature.identifier)
            console.log('Signature signature: ' + signature.signature)
            console.log('Signature nonce: ' + signature.nonce)
            console.log('Signature keyIdentifier: ' + signature.keyIdentifier)
        } catch (e) {
            console.error(e)
        }
    }

    const onPressSubscriptions = () => {
        Purchasely.presentSubscriptions()
    }

    const onPressRestore = async () => {
        try {
            const restored = await Purchasely.restoreAllProducts()
            console.log('Restoration success ? ' + restored)
        } catch (e) {
            console.error(e)
        }
    }

    const onPressSilentRestore = async () => {
        try {
            const restored = await Purchasely.silentRestoreAllProducts()
            console.log('Silent Restoration success ? ' + restored)
        } catch (e) {
            console.error(e)
        }
    }

    const onPressSynchronize = async () => {
        try {
            await Purchasely.synchronize()
            console.log('Synchronize done')
        } catch (e) {
            console.error('Synchronize failed', e)
        }
    }

    return (
        <SafeAreaView style={[styles.safeArea, backgroundStyle]}>
            <ScrollView
                contentInsetAdjustmentBehavior="automatic"
                style={styles.scrollView}
                contentContainerStyle={styles.contentContainer}
            >
                <Text style={styles.title}>Purchasely Example</Text>
                {/*<Header />*/}
                <Text>{DeviceInfo.getBundleId()}</Text>

                <View style={styles.buttonGrid}>
                    {buttons.map((btn, index) => (
                        <TouchableOpacity
                            key={index}
                            style={styles.button}
                            onPress={btn.onPress}
                        >
                            <Text style={styles.buttonText}>{btn.title}</Text>
                        </TouchableOpacity>
                    ))}
                </View>
            </ScrollView>
        </SafeAreaView>
    )
}

// Styles
const styles = StyleSheet.create({
    title: {
        marginTop: 12,
        marginBottom: 24,
        textAlign: 'center',
        fontSize: 36,
    },
    safeArea: {
        flex: 1,
    },
    scrollView: {
        flex: 1,
    },
    contentContainer: {
        flexGrow: 1,
        paddingHorizontal: 16,
        paddingBottom: 16,
    },
    buttonGrid: {
        flexDirection: 'row',
        flexWrap: 'wrap',
        justifyContent: 'space-between',
        gap: 10,
    },
    button: {
        backgroundColor: '#007AFF',
        borderRadius: 8,
        paddingVertical: 12,
        paddingHorizontal: 16,
        marginBottom: 10,
        width: '48%',
        alignItems: 'center',
    },
    buttonText: {
        color: 'white',
        fontWeight: 'bold',
        textAlign: 'center',
    },
})
