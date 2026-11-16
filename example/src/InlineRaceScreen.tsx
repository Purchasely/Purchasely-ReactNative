/**
 * T32 — embedded view torn down right after its mount (own process).
 *
 * Client crash (RN 0.86, bridge 6.1.1, Android): `No view found for id … for
 * fragment PurchaselyFragment`. The `create` command queues an asynchronous
 * fragment commit. When the host view unmounts, or leaves the window, before
 * that commit runs, AndroidX cannot find the container and the app dies.
 *
 * Earlier inline tests (T25, T28-T30) tear the view down only after
 * PRESENTATION_VIEWED, so the commit has always run. Here the teardown comes
 * in the same commit as the mount: a sibling placed AFTER the view runs its
 * mount effect right after the view's `create` effect.
 *
 * Steps (run in this order; `inline_race:<step>` runs one step alone):
 *   unmount — 20 cycles: mount, then unmount in the same React commit.
 *   screen  — 10 cycles: mount in screen A, then push screen B over it at once
 *             (no animation, so A leaves the window without an unmount).
 *   modal   — mount inside an RN <Modal> (a Dialog window): must render.
 *   health  — a normal mount after the churn: must render.
 *
 * A crash emits no marker: the host reads the missing [E2E:T32:*] marker and
 * the FATAL EXCEPTION in logcat. The race is timing based, so a fixed build
 * can only be shown green with some confidence, never proven green.
 */

import React, { useEffect, useRef, useState } from 'react'
import { Modal, StyleSheet, Text, View } from 'react-native'
import { ScreenStack, ScreenStackItem } from 'react-native-screens'
import Purchasely, { PLYPresentationView } from 'react-native-purchasely'

export const INLINE_RACE_PHASE = 'inline_race'
const API_KEY = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87'
const PLACEMENT = 'integration_test_audiences'
const UNMOUNT_CYCLES = 20
const SCREEN_CYCLES = 10
const STEPS = ['unmount', 'screen', 'modal', 'health'] as const
type Step = (typeof STEPS)[number]

function log(line: string) {
    console.log(`[E2E:T32] ${line}`)
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms))

/** Calls `onMount` from its mount effect, i.e. in the same commit as its siblings. */
function OnMount({ onMount }: { onMount: () => void }) {
    useEffect(onMount, [])  
    return null
}

type Stage =
    | { kind: 'idle' }
    | { kind: 'unmount'; cycle: number; mounted: boolean }
    | { kind: 'screen'; cycle: number; pushed: boolean }
    | { kind: 'modal' }
    | { kind: 'health' }

export default function InlineRaceScreen({ phase }: { phase: string }) {
    const only = phase.split(':')[1] as Step | undefined
    const [stage, setStage] = useState<Stage>({ kind: 'idle' })
    const [status, setStatus] = useState('starting')
    const viewedRef = useRef(0)

    useEffect(() => {
        run()
         
    }, [])

    async function waitViewed(before: number, ms: number): Promise<boolean> {
        const end = Date.now() + ms
        while (Date.now() < end) {
            if (viewedRef.current > before) return true
            await sleep(250)
        }
        return false
    }

    async function run() {
        console.log(`[E2E:SUITE:START] phase=${phase}`)
        const ok = await Purchasely.builder(API_KEY)
            .runningMode('full')
            .logLevel('debug')
            .stores(['google'])
            .start()
            .catch(() => false)
        if (!ok) {
            console.error('[E2E:T32:FAIL] SDK start failed')
            return
        }
        Purchasely.addEventListener((e: { name: string }) => {
            if (e.name === 'PRESENTATION_VIEWED') viewedRef.current += 1
        })

        const steps = only ? [only] : [...STEPS]
        try {
            for (const step of steps) {
                setStatus(step)
                log(`STEP:${step}:START`)
                if (step === 'unmount') {
                    for (let c = 1; c <= UNMOUNT_CYCLES; c++) {
                        setStage({ kind: 'unmount', cycle: c, mounted: true })
                        await sleep(400)
                    }
                    setStage({ kind: 'idle' })
                    await sleep(1500)
                } else if (step === 'screen') {
                    for (let c = 1; c <= SCREEN_CYCLES; c++) {
                        setStage({ kind: 'screen', cycle: c, pushed: false })
                        await sleep(800)
                        setStage({ kind: 'idle' })
                        await sleep(300)
                    }
                    await sleep(1500)
                } else {
                    const before = viewedRef.current
                    setStage({ kind: step })
                    const seen = await waitViewed(before, 30000)
                    setStage({ kind: 'idle' })
                    if (!seen) throw new Error(`${step}: no PRESENTATION_VIEWED in 30 s`)
                    await sleep(1000)
                }
                log(`STEP:${step}:OK`)
            }
            setStatus('pass')
            console.log(`[E2E:T32:PASS] steps=${steps.join(',')} survived; app alive`)
        } catch (e) {
            setStatus('fail')
            console.error(`[E2E:T32:FAIL] ${e instanceof Error ? e.message : String(e)}`)
        }
    }

    return (
        <View style={styles.fill}>
            <Text style={styles.status} testID="ply-e2e-t32-status">
                T32 inline race — {status} {'cycle' in stage ? `#${stage.cycle}` : ''}
            </Text>

            {stage.kind === 'unmount' && stage.mounted && (
                <View style={styles.slot} key={`u${stage.cycle}`}>
                    <PLYPresentationView placementId={PLACEMENT} flex={1} />
                    <OnMount onMount={() => setStage({ ...stage, mounted: false })} />
                </View>
            )}

            {stage.kind === 'screen' && (
                <View style={styles.fill} key={`s${stage.cycle}`}>
                    <ScreenStack style={styles.fill}>
                        <ScreenStackItem screenId={`t32-a-${stage.cycle}`} style={styles.fill}>
                            <View style={styles.slot}>
                                <PLYPresentationView placementId={PLACEMENT} flex={1} />
                                <OnMount onMount={() => setStage({ ...stage, pushed: true })} />
                            </View>
                        </ScreenStackItem>
                        {stage.pushed ? (
                            <ScreenStackItem
                                screenId={`t32-b-${stage.cycle}`}
                                stackAnimation="none"
                                style={[styles.fill, styles.screenB]}
                            >
                                <Text>T32 screen B</Text>
                            </ScreenStackItem>
                        ) : null}
                    </ScreenStack>
                </View>
            )}

            {stage.kind === 'modal' && (
                <Modal visible transparent={false} animationType="none">
                    <View style={styles.slot}>
                        <PLYPresentationView placementId={PLACEMENT} flex={1} />
                    </View>
                </Modal>
            )}

            {stage.kind === 'health' && (
                <View style={styles.slot}>
                    <PLYPresentationView placementId={PLACEMENT} flex={1} />
                </View>
            )}
        </View>
    )
}

const styles = StyleSheet.create({
    fill: { flex: 1 },
    status: { padding: 16, fontSize: 16 },
    slot: { height: 300 },
    screenB: { backgroundColor: 'white' },
})
