import { useEffect, useRef, useState } from 'react'
import { ActivityIndicator, Button, Text, View } from 'react-native'
import { NativeStackScreenProps } from '@react-navigation/native-stack'
import { Section } from './Section.tsx'
import {
    PLYPresentationView,
    PresentationBuilder,
    PresentationRequest,
    PresentPresentationResult,
    ProductResult,
} from 'react-native-purchasely'

/**
 * Demo of the v6 embedded-view `request` prop: preload a `PresentationRequest`
 * first, then hand it to `<PLYPresentationView request={...} />`. The native
 * view reuses the already-preloaded presentation (resolved by `requestId`)
 * instead of loading it a second time.
 */
export const PaywallPreloadedScreen: React.FC<NativeStackScreenProps<any>> = ({
    navigation,
    route,
}) => {
    const placementId: string = (route.params as any)?.placementId ?? 'nested'

    const [request, setRequest] = useState<PresentationRequest | null>(null)
    const [error, setError] = useState<string | null>(null)
    // Keep the request across re-renders so we can close it on unmount.
    const requestRef = useRef<PresentationRequest | null>(null)

    useEffect(() => {
        let cancelled = false

        const req = PresentationBuilder.placement(placementId).build()
        requestRef.current = req

        req.preload()
            .then((presentation) => {
                if (cancelled) return
                console.log(
                    '[PaywallPreloaded] preloaded',
                    presentation.screenId,
                    'requestId=',
                    req.requestId
                )
                setRequest(req)
            })
            .catch((e) => {
                if (!cancelled) setError(String(e?.message ?? e))
            })

        return () => {
            cancelled = true
            requestRef.current?.close()
        }
    }, [placementId])

    const callback = (result: PresentPresentationResult) => {
        console.log('[PaywallPreloaded] closed, result =', result.result)
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

    return (
        <View style={{ flex: 1 }}>
            <View
                style={{
                    flex: 2,
                    justifyContent: 'center',
                    alignItems: 'center',
                    backgroundColor: '#f0f0f0',
                }}
            >
                <Section>
                    <Text>Preloaded request demo (placement: {placementId})</Text>
                </Section>
                <Button title="← Back" onPress={() => navigation.goBack()} />
            </View>

            {request ? (
                <PLYPresentationView
                    flex={7}
                    request={request}
                    onPresentationClosed={callback}
                />
            ) : (
                <View
                    style={{
                        flex: 7,
                        justifyContent: 'center',
                        alignItems: 'center',
                    }}
                >
                    {error ? (
                        <Text>Preload failed: {error}</Text>
                    ) : (
                        <>
                            <ActivityIndicator />
                            <Text>Preloading {placementId}…</Text>
                        </>
                    )}
                </View>
            )}
        </View>
    )
}
