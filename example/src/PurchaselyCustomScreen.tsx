import React from 'react'
import {
    Button,
    SafeAreaView,
    ScrollView,
    StyleSheet,
    Text,
    View,
} from 'react-native'
import {
    type PLYCustomScreenProps,
    usePurchaselyCustomScreen,
} from 'react-native-purchasely'

/** Sample UI mounted by the native SDK for every client-authored flow step. */
export default function PurchaselyCustomScreen(
    props: PLYCustomScreenProps
): React.JSX.Element {
    const { presentation, executeConnection } = usePurchaselyCustomScreen(props)
    const connections = presentation.connections ?? []

    return (
        <SafeAreaView style={styles.safeArea}>
            <ScrollView contentContainerStyle={styles.content}>
                <Text style={styles.eyebrow}>PURCHASELY CUSTOM SCREEN</Text>
                <Text style={styles.title}>React Native BYOS screen</Text>
                <Text style={styles.copy}>
                    Expected placement: byos{`\n`}
                    Screen: {presentation.screenId ?? '—'}
                    {`\n`}
                    Flow: {presentation.flowId ?? '—'}
                    {`\n`}
                    Connections:{' '}
                    {connections
                        .map((connection) => connection.id)
                        .join(', ') || 'none'}
                </Text>
                <View style={styles.actions}>
                    {connections.map((connection, index) => (
                        <Button
                            key={connection.id ?? `connection-${index}`}
                            title={connection.id ?? '(default)'}
                            onPress={() =>
                                executeConnection(connection.id ?? undefined)
                            }
                        />
                    ))}
                </View>
            </ScrollView>
        </SafeAreaView>
    )
}

const styles = StyleSheet.create({
    safeArea: { flex: 1, backgroundColor: '#f7f4ff' },
    content: { flexGrow: 1, justifyContent: 'center', padding: 28, gap: 16 },
    eyebrow: { color: '#6941c6', fontSize: 12, fontWeight: '700' },
    title: { color: '#1d2939', fontSize: 30, fontWeight: '700' },
    copy: { color: '#475467', fontSize: 16, lineHeight: 24 },
    actions: { gap: 12, marginTop: 12 },
})
