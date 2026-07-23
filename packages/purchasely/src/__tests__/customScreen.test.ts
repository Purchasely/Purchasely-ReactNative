import { NativeModules } from 'react-native'
import {
    executeConnection,
    customScreenBack,
    customScreenClose,
} from '../customScreen'
import type { PLYPresentation } from '../presentationTypes'

jest.mock('react-native', () => ({
    NativeModules: {
        Purchasely: {
            executeConnection: jest.fn(),
            customScreenBack: jest.fn(),
            customScreenClose: jest.fn(),
        },
    },
}))

const native = NativeModules.Purchasely as any

const presentation = (over: Partial<PLYPresentation>): PLYPresentation =>
    ({ screenId: 'SCREEN', ...over } as PLYPresentation)

describe('customScreen navigation · presentation key resolution', () => {
    let warn: jest.SpyInstance

    beforeEach(() => {
        jest.clearAllMocks()
        warn = jest.spyOn(console, 'warn').mockImplementation(() => {})
    })

    afterEach(() => {
        warn.mockRestore()
    })

    it('uses customScreenId (provider path) and maps undefined connectionId to null', () => {
        executeConnection(presentation({ customScreenId: 'ply_cs_1' }))
        expect(native.executeConnection).toHaveBeenCalledWith('ply_cs_1', null)
    })

    it('falls back to requestId for standalone preloaded presentations', () => {
        executeConnection(presentation({ requestId: 'req_9' }), 'continue')
        expect(native.executeConnection).toHaveBeenCalledWith('req_9', 'continue')
    })

    it('prefers customScreenId over requestId when both are present', () => {
        customScreenBack(
            presentation({ customScreenId: 'ply_cs_2', requestId: 'req_9' })
        )
        expect(native.customScreenBack).toHaveBeenCalledWith('ply_cs_2')
    })

    it('no-ops and warns when the presentation carries neither key', () => {
        const orphan = presentation({})

        executeConnection(orphan, 'continue')
        customScreenBack(orphan)
        customScreenClose(orphan)

        expect(native.executeConnection).not.toHaveBeenCalled()
        expect(native.customScreenBack).not.toHaveBeenCalled()
        expect(native.customScreenClose).not.toHaveBeenCalled()
        expect(warn).toHaveBeenCalledTimes(3)
    })
})
