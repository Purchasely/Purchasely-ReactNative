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
    ProductResult,
} from 'react-native-purchasely'

import DeviceInfo from 'react-native-device-info'

export const HomeScreen: React.FC<NativeStackScreenProps<any>> = ({
    navigation,
}) => {
    const isDarkMode = useColorScheme() === 'dark'
    const backgroundStyle = {
        backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
    }

    // Boutons d'exemples
    const buttons = [
        { title: 'Display Presentation', onPress: () => onPressPresentation() },
        { title: 'Fetch Presentation', onPress: () => onPressFetch() },
        { title: 'Display Nested View', onPress: () => onPressNestedView() },
        {
            title: 'Show Presentation',
            onPress: () => onPressShowPresentation(),
        },
        {
            title: 'Hide Presentation',
            onPress: () => onPressHidePresentation(),
        },
        {
            title: 'Close Presentation',
            onPress: () => onPressClosePresentation(),
        },
        { title: 'Continue Action', onPress: () => onPressContinueAction() },
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
            const result = await Purchasely.presentPresentationForPlacement({
                placementVendorId: 'premium_support',
                // isFullscreen: true,
                loadingBackgroundColor: '#FFFFFFFF',
            })

            console.log('Result is ' + result.result)

            switch (result.result) {
                case ProductResult.PRODUCT_RESULT_PURCHASED:
                case ProductResult.PRODUCT_RESULT_RESTORED:
                    if (result.plan != null) {
                        console.log('User purchased ' + result.plan.name)
                    }

                    break
                case ProductResult.PRODUCT_RESULT_CANCELLED:
                    break
            }
        } catch (e) {
            console.error(e)
        }
    }

    const onPressFetch = async () => {
        try {
            const presentation = await Purchasely.fetchPresentation({
                placementId: 'FLOW',
                contentId: null,
            })

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

            //Display Purchasely paywall
             const result = await Purchasely.presentPresentation({
                 presentation: presentation,
             })

            console.log('---- Paywall Closed ----')
            console.log('Result is ' + result.result)

            switch (result.result) {
                case ProductResult.PRODUCT_RESULT_PURCHASED:
                case ProductResult.PRODUCT_RESULT_RESTORED:
                    if (result.plan != null) {
                        console.log('User purchased ' + result.plan.name)
                    }

                    break
                case ProductResult.PRODUCT_RESULT_CANCELLED:
                    console.log('User cancelled')
                    break
            }
        } catch (e) {
            console.error(e)
        }
    }

    const onPressNestedView = () => {
        navigation.navigate('Paywall')
    }

    const onPressShowPresentation = () => {
        Purchasely.showPresentation()
    }

    const onPressHidePresentation = () => {
        Purchasely.hidePresentation()
    }

    const onPressClosePresentation = () => {
        Purchasely.closePresentation()
    }

    const onPressContinueAction = () => {
        //Call this method to continue Purchasely action
        Purchasely.showPresentation()
        Purchasely.onProcessAction(true)
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
        Purchasely.synchronize()
        console.log('Synchronize done')
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
