import { Text, View } from 'react-native'
import { NativeStackScreenProps } from '@react-navigation/native-stack'
import { Header } from 'react-native/Libraries/NewAppScreen'
import { Section } from './Section.tsx'
import Purchasely, {
    PLYPresentationView,
    PresentPresentationResult,
    ProductResult,
    PurchaselyPresentation,
} from 'react-native-purchasely'
import { useEffect, useState } from 'react'

export const PaywallScreen: React.FC<NativeStackScreenProps<any>> = ({
    navigation,
}) => {
    const [purchaselyPresentation, setPurchaselyPresentation] =
        useState<PurchaselyPresentation>()

    useEffect(() => {
        fetchPresentation()
    }, [])

    const fetchPresentation = async () => {
        try {
            setPurchaselyPresentation(
                await Purchasely.fetchPresentation({
                    placementId: 'ONBOARDING',
                    contentId: null,
                })
            )
        } catch (e) {
            console.error(e)
        }
    }

    console.log('PRES', purchaselyPresentation)

    const callback = (result: PresentPresentationResult) => {
        console.log('### Paywall closed')
        console.log('### Result is ' + result.result)
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
        navigation.goBack()
    }

    if (purchaselyPresentation == null) {
        return (
            <View>
                <Text>Loading ...</Text>
            </View>
        )
    }

    return (
        <View style={{ flex: 1 }}>
            <Header />

            <PLYPresentationView
                placementId="ACCOUNT"
                flex={7}
                presentation={purchaselyPresentation}
                onPresentationClosed={(res: PresentPresentationResult) =>
                    callback(res)
                }
            />

            <View
                style={{
                    flex: 3,
                    justifyContent: 'center',
                    alignItems: 'center',
                }}
            >
                <Section>
                    <Text>Your own React Native content</Text>
                </Section>
            </View>
        </View>
    )
}
