/**
 * Unit tests for PLYPresentationView component
 */

import { mockConstants } from '../__mocks__/testUtils'

// Mock react-native before importing anything else
jest.mock('react-native', () => {
    // Use require inside the factory to avoid hoisting issues
    const React = require('react')

    // A dispatch-capable NativeEventEmitter stand-in: `addListener` registers
    // real handlers (returning a working `remove()`), and the test-only
    // `__emit` helper below invokes every handler currently registered for an
    // event name — lets tests simulate a native PURCHASELY_PRESENTATION_DISMISSED
    // dispatch instead of only asserting `addListener` was called.
    class MockEventEmitter {
        private listeners: Record<string, Array<(event: any) => void>> = {}

        addListener = jest.fn((eventName: string, handler: (event: any) => void) => {
            const forEvent = (this.listeners[eventName] ??= [])
            forEvent.push(handler)
            return {
                remove: jest.fn(() => {
                    this.listeners[eventName] = forEvent.filter((h) => h !== handler)
                }),
            }
        })

        removeAllListeners = jest.fn()

        __emit(eventName: string, event: any) {
            ;(this.listeners[eventName] ?? []).slice().forEach((handler) => handler(event))
        }
    }

    const mockEmitter = new MockEventEmitter()

    return {
        NativeModules: {
            Purchasely: {
                getConstants: jest.fn(() => mockConstants),
            },
        },
        NativeEventEmitter: jest.fn(() => mockEmitter),
        Platform: {
            OS: 'ios',
            select: jest.fn((obj: any) => obj.ios),
        },
        requireNativeComponent: jest.fn((name: string) => {
            // Return a simple functional component using React.forwardRef
            const MockComponent = React.forwardRef((props: any, ref: any) => {
                return React.createElement('PurchaselyView', { ...props, ref })
            })
            MockComponent.displayName = name
            return MockComponent
        }),
        findNodeHandle: jest.fn(() => 123),
        UIManager: {
            dispatchViewManagerCommand: jest.fn(),
            PurchaselyView: {
                Commands: {
                    create: 1,
                },
            },
        },
        __mockEmitter: mockEmitter,
    }
})

import { act, create } from 'react-test-renderer'
import { findNodeHandle, UIManager } from 'react-native'

// Import the component after mocking
import { PLYPresentationView } from '../components/PLYPresentationView'
import { PURCHASELY_PRESENTATION_EVENTS } from '../events'

// Get references to mocked functions
const mockedFindNodeHandle = findNodeHandle as jest.Mock
const mockedDispatchViewManagerCommand = UIManager.dispatchViewManagerCommand as jest.Mock
const { __mockEmitter: mockEmitter } = jest.requireMock('react-native') as {
    __mockEmitter: {
        addListener: jest.Mock
        __emit: (eventName: string, event: any) => void
    }
}

const DISMISSED = PURCHASELY_PRESENTATION_EVENTS.DISMISSED

describe('PLYPresentationView', () => {
    beforeEach(() => {
        jest.clearAllMocks()
    })

    describe('Rendering', () => {
        it('should render with placementId prop', async () => {
            let tree: any
            await act(async () => {
                tree = create(
                    <PLYPresentationView placementId="onboarding" />
                )
            })

            const instance = tree.root
            const purchaselyView = instance.findByType('PurchaselyView' as any)

            expect(purchaselyView).toBeDefined()
            expect(purchaselyView.props.placementId).toBe('onboarding')
        })

        it('should render with presentation prop', async () => {
            const presentation = {
                id: 'pres-123',
                placementId: 'placement-123',
                metadata: {},
                height: null,
            }

            let tree: any
            await act(async () => {
                tree = create(
                    <PLYPresentationView presentation={presentation} />
                )
            })

            const instance = tree.root
            const purchaselyView = instance.findByType('PurchaselyView' as any)

            expect(purchaselyView.props.presentation).toEqual(presentation)
        })

        it('should render with default flex value of 1', async () => {
            let tree: any
            await act(async () => {
                tree = create(
                    <PLYPresentationView placementId="onboarding" />
                )
            })

            const instance = tree.root
            const purchaselyView = instance.findByType('PurchaselyView' as any)

            expect(purchaselyView.props.style).toEqual({ flex: 1 })
        })

        it('should render with custom flex value', async () => {
            let tree: any
            await act(async () => {
                tree = create(
                    <PLYPresentationView placementId="onboarding" flex={2} />
                )
            })

            const instance = tree.root
            const purchaselyView = instance.findByType('PurchaselyView' as any)

            expect(purchaselyView.props.style).toEqual({ flex: 2 })
        })

        it('should render without placementId or presentation', async () => {
            let tree: any
            await act(async () => {
                tree = create(
                    <PLYPresentationView />
                )
            })

            const instance = tree.root
            const purchaselyView = instance.findByType('PurchaselyView' as any)

            expect(purchaselyView.props.placementId).toBeUndefined()
            expect(purchaselyView.props.presentation).toBeUndefined()
        })

        it('should always forward a generated viewId, even without request/presentation', async () => {
            let tree: any
            await act(async () => {
                tree = create(<PLYPresentationView placementId="onboarding" />)
            })

            const purchaselyView = tree.root.findByType('PurchaselyView' as any)
            expect(typeof purchaselyView.props.viewId).toBe('string')
            expect(purchaselyView.props.viewId.length).toBeGreaterThan(0)
        })
    })

    describe('request prop', () => {
        it('should forward the request requestId to the native view', async () => {
            // A preloaded PLYPresentationRequest exposes a non-null `requestId`.
            const request: any = { requestId: 'req-123' }

            let tree: any
            await act(async () => {
                tree = create(<PLYPresentationView request={request} />)
            })

            const purchaselyView = tree.root.findByType('PurchaselyView' as any)
            expect(purchaselyView.props.requestId).toBe('req-123')
        })

        it('should forward undefined when the request has not been preloaded', async () => {
            // Before preload(), requestId is null — the view falls back to
            // placementId / presentation.
            const request: any = { requestId: null }

            let tree: any
            await act(async () => {
                tree = create(<PLYPresentationView request={request} />)
            })

            const purchaselyView = tree.root.findByType('PurchaselyView' as any)
            expect(purchaselyView.props.requestId).toBeUndefined()
        })

        it('should leave requestId undefined when no request is passed', async () => {
            let tree: any
            await act(async () => {
                tree = create(<PLYPresentationView placementId="onboarding" />)
            })

            const purchaselyView = tree.root.findByType('PurchaselyView' as any)
            expect(purchaselyView.props.requestId).toBeUndefined()
        })
    })

    describe('Props', () => {
        it('should accept all optional props', async () => {
            const presentation = {
                id: 'pres-123',
                metadata: {},
                height: 500,
            }
            const onClosedCallback = jest.fn()

            let tree: any
            await act(async () => {
                tree = create(
                    <PLYPresentationView
                        placementId="onboarding"
                        presentation={presentation}
                        onPresentationClosed={onClosedCallback}
                        flex={3}
                    />
                )
            })

            const instance = tree.root
            const purchaselyView = instance.findByType('PurchaselyView' as any)

            expect(purchaselyView.props.placementId).toBe('onboarding')
            expect(purchaselyView.props.presentation).toEqual(presentation)
            expect(purchaselyView.props.style).toEqual({ flex: 3 })
        })
    })

    describe('dismiss routing', () => {
        it('does not subscribe when onPresentationClosed is not provided', async () => {
            await act(async () => {
                create(<PLYPresentationView placementId="onboarding" />)
            })

            expect(mockEmitter.addListener).not.toHaveBeenCalled()
        })

        it('delivers the full outcome for the requestId (preloaded) path', async () => {
            const request: any = { requestId: 'req-abc' }
            const onClosed = jest.fn()

            await act(async () => {
                create(<PLYPresentationView request={request} onPresentationClosed={onClosed} />)
            })

            await act(async () => {
                mockEmitter.__emit(DISMISSED, {
                    requestId: 'req-abc',
                    presentation: { screenId: 'scr-1', placementId: 'ONBOARDING' },
                    purchaseResult: 0,
                    plan: { vendorId: 'plan-1' },
                    closeReason: null,
                    error: null,
                })
            })

            expect(onClosed).toHaveBeenCalledTimes(1)
            expect(onClosed).toHaveBeenCalledWith({
                presentation: expect.objectContaining({ screenId: 'scr-1', id: 'scr-1' }),
                purchaseResult: 'purchased',
                plan: expect.objectContaining({ vendorId: 'plan-1' }),
                closeReason: null,
                error: null,
            })
        })

        it('delivers the outcome for the fresh placementId path via the generated viewId', async () => {
            const onClosed = jest.fn()

            let tree: any
            await act(async () => {
                tree = create(
                    <PLYPresentationView placementId="onboarding" onPresentationClosed={onClosed} />
                )
            })
            const viewId = tree.root.findByType('PurchaselyView' as any).props.viewId

            await act(async () => {
                mockEmitter.__emit(DISMISSED, {
                    requestId: viewId,
                    presentation: null,
                    purchaseResult: null,
                    plan: null,
                    closeReason: 'button',
                    error: null,
                })
            })

            expect(onClosed).toHaveBeenCalledWith({
                presentation: null,
                purchaseResult: null,
                plan: null,
                closeReason: 'button',
                error: null,
            })
        })

        it('delivers the outcome for the presentation prop path via the generated viewId', async () => {
            const onClosed = jest.fn()
            const presentation = { id: 'pres-123', placementId: 'placement-123' }

            let tree: any
            await act(async () => {
                tree = create(
                    <PLYPresentationView presentation={presentation} onPresentationClosed={onClosed} />
                )
            })
            const viewId = tree.root.findByType('PurchaselyView' as any).props.viewId

            await act(async () => {
                mockEmitter.__emit(DISMISSED, {
                    requestId: viewId,
                    presentation: { screenId: 'pres-123', placementId: 'placement-123' },
                    purchaseResult: 2,
                    plan: null,
                    closeReason: null,
                    error: null,
                })
            })

            expect(onClosed).toHaveBeenCalledTimes(1)
            expect(onClosed.mock.calls[0][0].purchaseResult).toBe('restored')
        })

        it('normalizes an error outcome and excludes closeReason', async () => {
            const request: any = { requestId: 'req-err' }
            const onClosed = jest.fn()

            await act(async () => {
                create(<PLYPresentationView request={request} onPresentationClosed={onClosed} />)
            })

            await act(async () => {
                mockEmitter.__emit(DISMISSED, {
                    requestId: 'req-err',
                    presentation: null,
                    purchaseResult: null,
                    plan: null,
                    closeReason: 'button',
                    error: { code: 'E1', message: 'boom', domain: 'io.purchasely' },
                })
            })

            expect(onClosed).toHaveBeenCalledWith({
                presentation: null,
                purchaseResult: null,
                plan: null,
                closeReason: null,
                error: { code: 'E1', message: 'boom', domain: 'io.purchasely' },
            })
        })

        it('ignores dismiss events for a different requestId', async () => {
            const request: any = { requestId: 'req-mine' }
            const onClosed = jest.fn()

            await act(async () => {
                create(<PLYPresentationView request={request} onPresentationClosed={onClosed} />)
            })

            await act(async () => {
                mockEmitter.__emit(DISMISSED, { requestId: 'req-other' })
            })

            expect(onClosed).not.toHaveBeenCalled()
        })

        it('routes independently across two simultaneous views', async () => {
            const requestA: any = { requestId: 'req-a' }
            const requestB: any = { requestId: 'req-b' }
            const onClosedA = jest.fn()
            const onClosedB = jest.fn()

            await act(async () => {
                create(
                    <>
                        <PLYPresentationView request={requestA} onPresentationClosed={onClosedA} />
                        <PLYPresentationView request={requestB} onPresentationClosed={onClosedB} />
                    </>
                )
            })

            await act(async () => {
                mockEmitter.__emit(DISMISSED, { requestId: 'req-a', purchaseResult: null })
            })

            expect(onClosedA).toHaveBeenCalledTimes(1)
            expect(onClosedB).not.toHaveBeenCalled()

            await act(async () => {
                mockEmitter.__emit(DISMISSED, { requestId: 'req-b', purchaseResult: null })
            })

            expect(onClosedA).toHaveBeenCalledTimes(1)
            expect(onClosedB).toHaveBeenCalledTimes(1)
        })

        it('removes its listener on unmount and stops receiving dismiss events', async () => {
            const request: any = { requestId: 'req-unmount' }
            const onClosed = jest.fn()

            let tree: any
            await act(async () => {
                tree = create(<PLYPresentationView request={request} onPresentationClosed={onClosed} />)
            })

            expect(mockEmitter.addListener).toHaveBeenCalledTimes(1)
            const { remove } = mockEmitter.addListener.mock.results[0]!.value

            await act(async () => {
                tree.unmount()
            })

            expect(remove).toHaveBeenCalled()

            mockEmitter.__emit(DISMISSED, { requestId: 'req-unmount' })
            expect(onClosed).not.toHaveBeenCalled()
        })
    })
})

describe('PLYPresentationView - Android Platform', () => {
    beforeEach(() => {
        jest.clearAllMocks()

        // Reset Platform.OS to Android
        const Platform = require('react-native').Platform
        Platform.OS = 'android'
    })

    afterEach(() => {
        // Reset Platform.OS back to iOS
        const Platform = require('react-native').Platform
        Platform.OS = 'ios'
    })

    it('should create fragment on Android', async () => {
        await act(async () => {
            create(
                <PLYPresentationView placementId="onboarding" />
            )
            // Wait for useEffect to run
            await new Promise(resolve => setTimeout(resolve, 10))
        })

        expect(mockedFindNodeHandle).toHaveBeenCalled()
        expect(mockedDispatchViewManagerCommand).toHaveBeenCalledWith(
            123,
            '1',
            [123]
        )
    })

    it('should pass ref prop on Android', async () => {
        const Platform = require('react-native').Platform
        Platform.OS = 'android'

        let tree: any
        await act(async () => {
            tree = create(
                <PLYPresentationView placementId="onboarding" />
            )
        })

        const instance = tree.root
        const purchaselyView = instance.findByType('PurchaselyView' as any)

        // On Android, the ref should be passed
        expect(purchaselyView.props).toHaveProperty('ref')
    })
})
