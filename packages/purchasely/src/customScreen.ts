import { useCallback } from 'react'
import { NativeModules } from 'react-native'

import type {
    PLYCustomScreenProps,
    PLYCustomScreenProviderOptions,
    PLYPresentation,
} from './presentationTypes'

const presentationKey = (presentation: PLYPresentation): string | null =>
    presentation.customScreenId ?? presentation.requestId ?? null

/**
 * Resolve the native key for a presentation and run `action` with it. When the
 * presentation carries neither a `customScreenId` (provider path) nor a
 * `requestId` (preloaded standalone path), warn and no-op instead of calling
 * native with an empty key.
 */
const withPresentationKey = (
    presentation: PLYPresentation,
    call: string,
    action: (key: string) => void
): void => {
    const key = presentationKey(presentation)
    if (!key) {
        console.warn(
            `[Purchasely] ${call} ignored: use the presentation supplied to the Custom Screen or returned by preload()`
        )
        return
    }
    action(key)
}

/** Register or replace the React component used for Purchasely Custom Screen flow steps. */
export function setCustomScreenProvider(
    options: PLYCustomScreenProviderOptions
): Promise<void> {
    return Promise.resolve(
        NativeModules.Purchasely.setCustomScreenProvider(options.componentName)
    )
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
    withPresentationKey(presentation, 'executeConnection', (key) =>
        NativeModules.Purchasely.executeConnection(key, connectionId ?? null)
    )
}

/** Navigate to the previous step in the current Purchasely flow. */
export function customScreenBack(presentation: PLYPresentation): void {
    withPresentationKey(presentation, 'customScreenBack', (key) =>
        NativeModules.Purchasely.customScreenBack(key)
    )
}

/** Close the Purchasely flow containing this Custom Screen. */
export function customScreenClose(presentation: PLYPresentation): void {
    withPresentationKey(presentation, 'customScreenClose', (key) =>
        NativeModules.Purchasely.customScreenClose(key)
    )
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
