import { Button, Text, View } from 'react-native'
import { NativeStackScreenProps } from '@react-navigation/native-stack'
import { Section } from './Section.tsx'
import {
    PLYPresentationView,
    PresentPresentationResult,
    ProductResult,
} from 'react-native-purchasely'

export const PaywallScreen: React.FC<NativeStackScreenProps<any>> = ({
    navigation,
    route,
}) => {
    // the embedded PLYPresentationView is driven by a placement id.
    const placementId: string | null =
        (route.params as any)?.placementId ?? null

    console.log('### Paywall screen')
    console.log('placementId', placementId)

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

    if (placementId === null) {
        return (
            <View>
                <Text>No placement provided</Text>
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
                flex={7}
                placementId={placementId}
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
