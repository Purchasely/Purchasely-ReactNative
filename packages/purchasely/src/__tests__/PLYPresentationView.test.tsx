/**
 * Unit tests for PLYPresentationView component
 */

// Mock react-native before importing anything else
jest.mock('react-native', () => {
    // Use require inside the factory to avoid hoisting issues
    const React = require('react')

    const mockOnPresentationClosed = jest.fn().mockResolvedValue({
        result: 0,
        plan: null,
    })

    return {
        NativeModules: {
            Purchasely: {
                getConstants: jest.fn(() => ({})),
            },
            PurchaselyView: {
                onPresentationClosed: mockOnPresentationClosed,
            },
        },
        NativeEventEmitter: jest.fn(() => ({
            addListener: jest.fn(() => ({ remove: jest.fn() })),
            removeAllListeners: jest.fn(),
        })),
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
    }
})

import { act, create } from 'react-test-renderer'
import { NativeModules, findNodeHandle, UIManager } from 'react-native'

// Import the component after mocking
import { PLYPresentationView } from '../components/PLYPresentationView'

// Get references to mocked functions
const mockedOnPresentationClosed = NativeModules.PurchaselyView.onPresentationClosed as jest.Mock
const mockedFindNodeHandle = findNodeHandle as jest.Mock
const mockedDispatchViewManagerCommand = UIManager.dispatchViewManagerCommand as jest.Mock

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
    })

    describe('Callbacks', () => {
        it('should call onPresentationClosed callback when provided', async () => {
            const onClosedCallback = jest.fn()

            await act(async () => {
                create(
                    <PLYPresentationView
                        placementId="onboarding"
                        onPresentationClosed={onClosedCallback}
                    />
                )
                // Allow async effects to complete
                await new Promise(resolve => setTimeout(resolve, 10))
            })

            expect(mockedOnPresentationClosed).toHaveBeenCalled()
            expect(onClosedCallback).toHaveBeenCalledWith({
                result: 0,
                plan: null,
            })
        })

        it('should not call native onPresentationClosed when callback not provided', async () => {
            await act(async () => {
                create(
                    <PLYPresentationView placementId="onboarding" />
                )
                await new Promise(resolve => setTimeout(resolve, 10))
            })

            // The native method should not be called when no callback is provided
            // because the useEffect has an early return
            expect(mockedOnPresentationClosed).not.toHaveBeenCalled()
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
        // Command ID is now numeric (1) instead of string ('1') for New Architecture compatibility
        expect(mockedDispatchViewManagerCommand).toHaveBeenCalledWith(
            123,
            1,
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
