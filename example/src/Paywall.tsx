import { Button, Text, View } from 'react-native'
import { NativeStackScreenProps } from '@react-navigation/native-stack'
import { Section } from './Section.tsx'
import {
    PLYPresentationView,
    type PLYPresentationOutcome,
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

    const callback = (outcome: PLYPresentationOutcome) => {
        console.log('### Paywall closed')
        console.log(
            '### purchaseResult =',
            outcome.purchaseResult,
            'closeReason =',
            outcome.closeReason
        )
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
                onPresentationClosed={callback}
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
