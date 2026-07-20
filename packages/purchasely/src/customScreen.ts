import { useCallback } from 'react'
import { NativeModules } from 'react-native'

import type {
    PLYCustomScreenProps,
    PLYCustomScreenProviderOptions,
    PLYPresentation,
} from './presentationTypes'

const presentationKey = (presentation: PLYPresentation): string | null =>
    presentation.customScreenId ?? presentation.requestId ?? null

/** Register or replace the React component used for Purchasely Custom Screen flow steps. */
export function setCustomScreenProvider(
    options: PLYCustomScreenProviderOptions
): void {
    NativeModules.Purchasely.setCustomScreenProvider(options.componentName)
}

/** Remove the currently registered Custom Screen provider. */
export function removeCustomScreenProvider(): void {
    NativeModules.Purchasely.removeCustomScreenProvider()
}

/** Execute a named connection, or the default connection when no id is supplied. */
export function executeConnection(
    presentation: PLYPresentation,
    connectionId?: string
): void {
    const key = presentationKey(presentation)
    if (!key) {
        console.warn(
            '[Purchasely] executeConnection ignored: use the presentation supplied to the Custom Screen or returned by preload()'
        )
        return
    }
    NativeModules.Purchasely.executeConnection(key, connectionId ?? null)
}

/** Navigate to the previous step in the current Purchasely flow. */
export function customScreenBack(presentation: PLYPresentation): void {
    const key = presentationKey(presentation)
    if (!key) {
        console.warn(
            '[Purchasely] customScreenBack ignored: presentation has no native key'
        )
        return
    }
    NativeModules.Purchasely.customScreenBack(key)
}

/** Close the Purchasely flow containing this Custom Screen. */
export function customScreenClose(presentation: PLYPresentation): void {
    const key = presentationKey(presentation)
    if (!key) {
        console.warn(
            '[Purchasely] customScreenClose ignored: presentation has no native key'
        )
        return
    }
    NativeModules.Purchasely.customScreenClose(key)
}

/** Convenience hook binding Custom Screen navigation to the delivered presentation. */
export function usePurchaselyCustomScreen(props: PLYCustomScreenProps): {
    presentation: PLYPresentation
    executeConnection: (connectionId?: string) => void
    back: () => void
    close: () => void
} {
    const { presentation } = props
    const execute = useCallback(
        (connectionId?: string) =>
            executeConnection(presentation, connectionId),
        [presentation]
    )
    const back = useCallback(
        () => customScreenBack(presentation),
        [presentation]
    )
    const close = useCallback(
        () => customScreenClose(presentation),
        [presentation]
    )

    return { presentation, executeConnection: execute, back, close }
}
