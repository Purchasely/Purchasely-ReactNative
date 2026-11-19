/**
 * User subscription status listener (6.3.0, MOB-646).
 *
 * The emitter stand-in dispatches for real, so a test can emit a native
 * USER_SUBSCRIPTION_STATUS_LISTENER event and see which listeners get it.
 */
jest.mock('react-native', () => {
    const { mockConstants: constants } = require('../__mocks__/testUtils')
    const listeners: Record<string, Array<(event: any) => void>> = {}
    return {
        NativeModules: {
            Purchasely: {
                getConstants: jest.fn(() => constants),
                startUserSubscriptionStatusListener: jest.fn(),
                stopUserSubscriptionStatusListener: jest.fn(),
                userLogin: jest.fn().mockResolvedValue(true),
                userLogout: jest.fn(),
                addListener: jest.fn(),
                removeListeners: jest.fn(),
                __emit: (name: string, event: any) =>
                    (listeners[name] ?? []).slice().forEach((l) => l(event)),
            },
        },
        NativeEventEmitter: jest.fn(() => ({
            addListener: (name: string, cb: (event: any) => void) => {
                ;(listeners[name] ??= []).push(cb)
                return {
                    remove: () => {
                        listeners[name] = (listeners[name] ?? []).filter((l) => l !== cb)
                    },
                }
            },
            removeAllListeners: jest.fn(),
        })),
        Platform: { OS: 'ios', select: (obj: any) => obj.ios },
        requireNativeComponent: jest.fn(() => 'PurchaselyView'),
        findNodeHandle: jest.fn(),
        UIManager: {},
    }
})

import { NativeModules } from 'react-native'
import Purchasely from '../index'
import type { PLYUserSubscriptionStatus } from '../index'

const native = NativeModules.Purchasely as any
const EVENT = 'USER_SUBSCRIPTION_STATUS_LISTENER'

const purchased: PLYUserSubscriptionStatus = {
    isActive: true,
    reason: 'PURCHASED',
    subscription: { plan: { vendorId: 'plan-1' } } as any,
}

// The listener count is module state: every test removes what it added.
const active: Array<{ remove: () => void }> = []
const add = (cb: jest.Mock) => {
    const subscription = Purchasely.addUserSubscriptionStatusListener(cb)
    active.push(subscription)
    return subscription
}

describe('user subscription status listener', () => {
    afterEach(() => {
        active.splice(0).forEach((s) => s.remove())
        jest.clearAllMocks()
    })

    it('delivers the payload to the listener and starts the native listener', () => {
        const callback = jest.fn()
        const subscription = add(callback)

        expect(native.startUserSubscriptionStatusListener).toHaveBeenCalledTimes(1)
        native.__emit(EVENT, purchased)

        expect(callback).toHaveBeenCalledTimes(1)
        expect(callback).toHaveBeenCalledWith(purchased)
        Purchasely.removeUserSubscriptionStatusListener(subscription)
    })

    it('stops the delivery after remove', () => {
        const callback = jest.fn()
        const subscription = add(callback)
        Purchasely.removeUserSubscriptionStatusListener(subscription)

        native.__emit(EVENT, purchased)

        expect(callback).not.toHaveBeenCalled()
    })

    it('delivers to two listeners, and removing one keeps the other', () => {
        const first = jest.fn()
        const second = jest.fn()
        const firstSubscription = add(first)
        add(second)

        native.__emit(EVENT, purchased)
        expect(first).toHaveBeenCalledWith(purchased)
        expect(second).toHaveBeenCalledWith(purchased)

        Purchasely.removeUserSubscriptionStatusListener(firstSubscription)
        native.__emit(EVENT, purchased)
        expect(first).toHaveBeenCalledTimes(1)
        expect(second).toHaveBeenCalledTimes(2)
    })

    it('passes a status call with a null reason and a null subscription unchanged', () => {
        const callback = jest.fn()
        add(callback)

        native.__emit(EVENT, { isActive: false, reason: null, subscription: null })

        expect(callback).toHaveBeenCalledWith({ isActive: false, reason: null, subscription: null })
    })

    it('keeps the purchased listener on its own event', () => {
        const callback = jest.fn()
        add(callback)

        native.__emit('PURCHASE_LISTENER', {})

        expect(callback).not.toHaveBeenCalled()
    })

    describe('several listeners', () => {
        const flush = () => new Promise<void>((resolve) => setTimeout(resolve, 0))
        it('replays the last status to a new listener only, once', async () => {
            const first = jest.fn()
            const second = jest.fn()
            add(first)
            native.__emit(EVENT, purchased)

            add(second)
            expect(second).not.toHaveBeenCalled()
            await flush()

            expect(second).toHaveBeenCalledTimes(1)
            expect(second).toHaveBeenCalledWith(purchased)
            expect(first).toHaveBeenCalledTimes(1)
            expect(native.startUserSubscriptionStatusListener).toHaveBeenCalledTimes(1)
        })

        it('does not replay when nothing was received', async () => {
            const second = jest.fn()
            add(jest.fn())
            add(second)
            await flush()

            expect(second).not.toHaveBeenCalled()
        })

        it('does not replay to a listener removed before the replay', async () => {
            add(jest.fn())
            native.__emit(EVENT, purchased)
            const second = jest.fn()
            const subscription = add(second)
            subscription.remove()
            await flush()

            expect(second).not.toHaveBeenCalled()
        })

        it('does not replay the previous user status after userLogout or userLogin', async () => {
            add(jest.fn())
            native.__emit(EVENT, purchased)
            Purchasely.userLogout()
            const afterLogout = jest.fn()
            add(afterLogout)
            await flush()
            expect(afterLogout).not.toHaveBeenCalled()

            native.__emit(EVENT, purchased)
            await Purchasely.userLogin('user-b')
            const afterLogin = jest.fn()
            add(afterLogin)
            await flush()
            expect(afterLogin).not.toHaveBeenCalled()
        })

        it('drops a queued replay when the user logs out in the same turn', async () => {
            add(jest.fn())
            native.__emit(EVENT, purchased)
            const late = jest.fn()
            add(late)
            Purchasely.userLogout()
            await flush()
            expect(late).not.toHaveBeenCalled()
        })

        it('counts a double remove once', () => {
            const first = add(jest.fn())
            add(jest.fn())

            first.remove()
            Purchasely.removeUserSubscriptionStatusListener(first as any)

            expect(native.stopUserSubscriptionStatusListener).not.toHaveBeenCalled()
        })

        it('stops the native listener on the last remove and starts it again on the next add', async () => {
            const first = add(jest.fn())
            const second = add(jest.fn())
            native.__emit(EVENT, purchased)

            first.remove()
            expect(native.stopUserSubscriptionStatusListener).not.toHaveBeenCalled()
            Purchasely.removeUserSubscriptionStatusListener(second as any)
            expect(native.stopUserSubscriptionStatusListener).toHaveBeenCalledTimes(1)

            const third = jest.fn()
            add(third)
            await flush()

            expect(native.startUserSubscriptionStatusListener).toHaveBeenCalledTimes(2)
            expect(third).not.toHaveBeenCalled()
        })
    })
})
