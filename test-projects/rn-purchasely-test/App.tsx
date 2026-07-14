import React, { useCallback, useEffect, useState } from 'react'
import {
    StyleSheet,
    Text,
    View,
    TouchableOpacity,
    ActivityIndicator,
    StatusBar,
    Alert,
    ScrollView,
} from 'react-native'
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context'
import Purchasely, {
    PLYPresentationView,
    PLYPresentationType,
    PLYLoadedPresentation,
    PLYPresentationOutcome,
} from 'react-native-purchasely'

function App(): React.JSX.Element {
    const [isConfigured, setIsConfigured] = useState(false)
    const [isLoading, setIsLoading] = useState(true)
    const [presentation, setPresentation] =
        useState<PLYLoadedPresentation | null>(null)
    const [statusMessage, setStatusMessage] = useState(
        'Initializing Purchasely SDK...'
    )
    const [validationMode, setValidationMode] = useState<
        'fullscreen' | 'embedded'
    >('fullscreen')

    const fetchPresentationData = useCallback(async () => {
        try {
            setStatusMessage('Fetching presentation...')

            const fetchedPresentation = await Purchasely.presentation
                .placement('ONBOARDING')
                .build()
                .preload()

            setPresentation(fetchedPresentation)
            setStatusMessage('Presentation fetched successfully!')
            console.log('Presentation fetched:', fetchedPresentation)
        } catch (error) {
            setStatusMessage(`Fetch error: ${error}`)
            console.error('Error fetching presentation:', error)
        }
    }, [])

    const initializePurchasely = useCallback(async () => {
        try {
            setStatusMessage('Starting Purchasely SDK...')

            const configured = await Purchasely.builder(
                'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d'
            )
                .runningMode('full')
                .logLevel('debug')
                .allowDeeplink(true)
                .stores(['google'])
                .storekitVersion('storeKit2')
                .start()

            if (configured) {
                setIsConfigured(true)
                setStatusMessage('SDK initialized successfully!')
                console.log('Purchasely SDK initialized successfully')

                // Set language
                Purchasely.setLanguage('en')

                // Fetch presentation after SDK is configured
                await fetchPresentationData()
            } else {
                setStatusMessage('SDK initialization failed')
                console.error('Purchasely SDK initialization failed')
            }
        } catch (error) {
            setStatusMessage(`SDK Error: ${error}`)
            console.error('Purchasely SDK initialization error:', error)
        } finally {
            setIsLoading(false)
        }
    }, [fetchPresentationData])

    useEffect(() => {
        initializePurchasely()
    }, [initializePurchasely])

    const handlePresentationOutcome = (outcome: PLYPresentationOutcome) => {
        if (outcome.error) {
            Alert.alert('Error', outcome.error.message)
            return
        }

        switch (outcome.purchaseResult) {
            case 'purchased':
                Alert.alert(
                    'Success',
                    `Purchased: ${outcome.plan?.name || 'Unknown plan'}`
                )
                break
            case 'restored':
                Alert.alert(
                    'Success',
                    `Restored: ${outcome.plan?.name || 'Unknown plan'}`
                )
                break
            case 'cancelled':
                console.log('User cancelled')
                break
            default:
                console.log('Presentation closed:', outcome.closeReason)
        }
    }

    const showPresentation = async () => {
        if (!presentation) {
            Alert.alert(
                'Error',
                'No presentation available. Please fetch first.'
            )
            return
        }

        try {
            // Check presentation type
            if (presentation.type === PLYPresentationType.DEACTIVATED) {
                Alert.alert('Info', 'This presentation is deactivated')
                return
            }

            if (presentation.type === PLYPresentationType.CLIENT) {
                Alert.alert('Info', 'This is a client-side presentation')
                return
            }

            handlePresentationOutcome(
                await presentation.display({ type: 'fullScreen' })
            )
        } catch (error) {
            Alert.alert('Error', `Failed to show presentation: ${error}`)
            console.error('Error presenting:', error)
        }
    }

    const presentDirectly = async () => {
        try {
            const outcome = await Purchasely.presentation
                .placement('ONBOARDING')
                .build()
                .display({ type: 'fullScreen' })
            handlePresentationOutcome(outcome)
        } catch (error) {
            Alert.alert('Error', `Failed to present: ${error}`)
            console.error('Error presenting directly:', error)
        }
    }

    const showEmbeddedPresentation = () => {
        setValidationMode('embedded')
        setStatusMessage('Embedded presentation mounted.')
    }

    const showFullscreenPresentation = () => {
        setValidationMode('fullscreen')
        showPresentation()
    }

    return (
        <SafeAreaProvider>
            <SafeAreaView
                style={styles.container}
                edges={['top', 'right', 'bottom', 'left']}
            >
                <StatusBar barStyle="dark-content" backgroundColor="#f5f5f5" />

                <ScrollView contentContainerStyle={styles.scrollContent}>
                    <View style={styles.header}>
                        <Text style={styles.title}>Purchasely RN CLI Test</Text>
                        <Text style={styles.subtitle}>
                            SDK Integration Demo
                        </Text>
                    </View>

                    <View style={styles.statusContainer}>
                        <Text style={styles.statusLabel}>Status:</Text>
                        <Text style={styles.statusText}>{statusMessage}</Text>
                        {isLoading && (
                            <ActivityIndicator
                                style={styles.loader}
                                color="#007AFF"
                            />
                        )}
                    </View>

                    <View style={styles.infoContainer}>
                        <Text style={styles.infoTitle}>SDK Configuration</Text>
                        <Text style={styles.infoText}>
                            Configured: {isConfigured ? 'Yes' : 'No'}
                        </Text>
                        <Text style={styles.infoText}>
                            Presentation:{' '}
                            {presentation ? 'Loaded' : 'Not loaded'}
                        </Text>
                        {presentation && (
                            <>
                                <Text style={styles.infoText}>
                                    Type: {presentation.type}
                                </Text>
                                <Text style={styles.infoText}>
                                    ID: {presentation.id || 'N/A'}
                                </Text>
                            </>
                        )}
                    </View>

                    <View style={styles.buttonContainer}>
                        <TouchableOpacity
                            style={[
                                styles.button,
                                !isConfigured && styles.buttonDisabled,
                            ]}
                            onPress={fetchPresentationData}
                            disabled={!isConfigured}
                        >
                            <Text style={styles.buttonText}>
                                Fetch Presentation
                            </Text>
                        </TouchableOpacity>

                        <TouchableOpacity
                            style={[
                                styles.button,
                                styles.buttonPrimary,
                                !presentation && styles.buttonDisabled,
                            ]}
                            onPress={showFullscreenPresentation}
                            disabled={!presentation}
                        >
                            <Text style={styles.buttonText}>
                                Validate Fullscreen Modal
                            </Text>
                        </TouchableOpacity>

                        <TouchableOpacity
                            style={[
                                styles.button,
                                styles.buttonSecondary,
                                !isConfigured && styles.buttonDisabled,
                            ]}
                            onPress={presentDirectly}
                            disabled={!isConfigured}
                        >
                            <Text style={styles.buttonText}>
                                Present Directly (Fullscreen)
                            </Text>
                        </TouchableOpacity>

                        <TouchableOpacity
                            style={[
                                styles.button,
                                styles.buttonEmbedded,
                                !isConfigured && styles.buttonDisabled,
                            ]}
                            onPress={showEmbeddedPresentation}
                            disabled={!isConfigured}
                        >
                            <Text style={styles.buttonText}>
                                Validate Embedded Paywall
                            </Text>
                        </TouchableOpacity>
                    </View>

                    {validationMode === 'embedded' && isConfigured && (
                        <View style={styles.embeddedContainer}>
                            <Text style={styles.embeddedTitle}>
                                Embedded PLYPresentationView
                            </Text>
                            <Text style={styles.embeddedHint}>
                                Verify this paywall remains within the safe area
                                while resizing, rotating, and showing the
                                keyboard.
                            </Text>
                            <View style={styles.embeddedPaywall}>
                                <PLYPresentationView
                                    placementId="ONBOARDING"
                                    onPresentationClosed={(result) => {
                                        setStatusMessage(
                                            `Embedded presentation closed: ${result.result}`
                                        )
                                    }}
                                />
                            </View>
                        </View>
                    )}

                    <View style={styles.footer}>
                        <Text style={styles.footerText}>
                            This app demonstrates the Purchasely React Native
                            SDK
                        </Text>
                        <Text style={styles.footerText}>
                            with React Native CLI
                        </Text>
                    </View>
                </ScrollView>
            </SafeAreaView>
        </SafeAreaProvider>
    )
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#f5f5f5',
    },
    scrollContent: {
        flexGrow: 1,
    },
    header: {
        padding: 20,
        alignItems: 'center',
        backgroundColor: '#fff',
        borderBottomWidth: 1,
        borderBottomColor: '#e0e0e0',
    },
    title: {
        fontSize: 24,
        fontWeight: 'bold',
        color: '#333',
    },
    subtitle: {
        fontSize: 14,
        color: '#666',
        marginTop: 4,
    },
    statusContainer: {
        padding: 16,
        backgroundColor: '#fff',
        margin: 16,
        borderRadius: 8,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 1 },
        shadowOpacity: 0.1,
        shadowRadius: 2,
        elevation: 2,
    },
    statusLabel: {
        fontSize: 12,
        color: '#666',
        fontWeight: '600',
    },
    statusText: {
        fontSize: 14,
        color: '#333',
        marginTop: 4,
    },
    loader: {
        marginTop: 8,
    },
    infoContainer: {
        padding: 16,
        backgroundColor: '#fff',
        marginHorizontal: 16,
        borderRadius: 8,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 1 },
        shadowOpacity: 0.1,
        shadowRadius: 2,
        elevation: 2,
    },
    infoTitle: {
        fontSize: 16,
        fontWeight: '600',
        color: '#333',
        marginBottom: 8,
    },
    infoText: {
        fontSize: 14,
        color: '#666',
        marginTop: 4,
    },
    buttonContainer: {
        padding: 16,
        gap: 12,
    },
    button: {
        backgroundColor: '#007AFF',
        padding: 16,
        borderRadius: 8,
        alignItems: 'center',
    },
    buttonPrimary: {
        backgroundColor: '#34C759',
    },
    buttonSecondary: {
        backgroundColor: '#FF9500',
    },
    buttonEmbedded: {
        backgroundColor: '#5856D6',
    },
    buttonDisabled: {
        backgroundColor: '#ccc',
    },
    buttonText: {
        color: '#fff',
        fontSize: 16,
        fontWeight: '600',
    },
    embeddedContainer: {
        marginHorizontal: 16,
        padding: 16,
        backgroundColor: '#fff',
        borderRadius: 8,
        gap: 8,
    },
    embeddedTitle: {
        fontSize: 16,
        fontWeight: '600',
        color: '#333',
    },
    embeddedHint: {
        fontSize: 12,
        color: '#666',
    },
    embeddedPaywall: {
        height: 420,
        overflow: 'hidden',
    },
    footer: {
        padding: 16,
        alignItems: 'center',
        marginTop: 'auto',
    },
    footerText: {
        fontSize: 12,
        color: '#999',
        textAlign: 'center',
    },
})

export default App
