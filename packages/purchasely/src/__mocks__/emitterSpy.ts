/**
 * Shared spy for the native event emitter.
 *
 * `startBuilder.ts` reaches the emitter through `redemption.ts`, which builds
 * it once and keeps it. A `jest.fn()` factory that returns a fresh object per
 * construction therefore hides every call behind an instance the test cannot
 * see. This module holds one set of spies so a test can assert on them and,
 * importantly, inspect the subscriptions handed back.
 */
type Subscription = { remove: jest.Mock }

const subscriptions: Subscription[] = []
let onAddHook: (() => void) | undefined

const addListener = jest.fn((_event: string, _callback: unknown) => {
    onAddHook?.()
    const subscription: Subscription = { remove: jest.fn() }
    subscriptions.push(subscription)
    return subscription
})

const removeAllListeners = jest.fn()

const reset = () => {
    addListener.mockClear()
    removeAllListeners.mockClear()
    subscriptions.length = 0
    onAddHook = undefined
}

/** Run `fn` each time a listener is added, to record ordering. */
const onAdd = (fn: () => void) => {
    onAddHook = fn
}

export default { addListener, removeAllListeners, subscriptions, reset, onAdd }
