import { Button, Text, View } from 'react-native'
import { NativeStackScreenProps } from '@react-navigation/native-stack'
import { Section } from './Section.tsx'
import {
    PLYPresentationView,
    PresentPresentationResult,
    ProductResult,
    PurchaselyPresentation,
} from 'react-native-purchasely'

export const PaywallScreen: React.FC<NativeStackScreenProps<any>> = ({
    navigation,
    route,
}) => {
    const purchaselyPresentation: PurchaselyPresentation | null =
        (route.params as any)?.presentation ?? null

    console.log('### Paywall screen')
    console.log('presentation', purchaselyPresentation)
    console.log('presentation height : ', purchaselyPresentation?.height)

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

    if (purchaselyPresentation === null) {
        return (
            <View>
                <Text>No presentation (not fetched yet)</Text>
            </View>
        )
    }

    return (
        <View style={{ flex: 1 }}>
            <View
                style={{
                    flex: 3,
                    justifyContent: 'center',
                    alignItems: 'center',
                    backgroundColor: '#f0f0f0',
                }}
            >
                <Section>
                    <Text>Top content</Text>
                </Section>
                <Button title="← Back" onPress={() => navigation.goBack()} />
            </View>
            <PLYPresentationView
                //placementId="ACCOUNT"
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
