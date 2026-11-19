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

describe('user subscription status listener', () => {
    beforeEach(() => {
        jest.clearAllMocks()
    })

    it('delivers the payload to the listener and starts the native listener', () => {
        const callback = jest.fn()
        const subscription = Purchasely.addUserSubscriptionStatusListener(callback)

        expect(native.startUserSubscriptionStatusListener).toHaveBeenCalledTimes(1)
        native.__emit(EVENT, purchased)

        expect(callback).toHaveBeenCalledTimes(1)
        expect(callback).toHaveBeenCalledWith(purchased)
        Purchasely.removeUserSubscriptionStatusListener(subscription)
    })

    it('stops the delivery after remove', () => {
        const callback = jest.fn()
        const subscription = Purchasely.addUserSubscriptionStatusListener(callback)
        Purchasely.removeUserSubscriptionStatusListener(subscription)

        native.__emit(EVENT, purchased)

        expect(callback).not.toHaveBeenCalled()
    })

    it('delivers to two listeners, and removing one keeps the other', () => {
        const first = jest.fn()
        const second = jest.fn()
        const firstSubscription = Purchasely.addUserSubscriptionStatusListener(first)
        Purchasely.addUserSubscriptionStatusListener(second)

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
        Purchasely.addUserSubscriptionStatusListener(callback)

        native.__emit(EVENT, { isActive: false, reason: null, subscription: null })

        expect(callback).toHaveBeenCalledWith({ isActive: false, reason: null, subscription: null })
    })

    it('keeps the purchased listener on its own event', () => {
        const callback = jest.fn()
        Purchasely.addUserSubscriptionStatusListener(callback)

        native.__emit('PURCHASE_LISTENER', {})

        expect(callback).not.toHaveBeenCalled()
    })
})
