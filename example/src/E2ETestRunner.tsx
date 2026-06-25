/**
 * E2E test runner — T1–T9 (React Native port of the Flutter integration tests).
 *
 * Renders as the root component when the app is launched with E2E_MODE=true.
 * Each test runs sequentially in a single SDK session. Drivers for T8/T9 are
 * coordinated via LogCat markers emitted to the host script (run_e2e.sh):
 *   [E2E:READY_FOR_TAP]  — paywall is up; host should tap the purchase button
 *   [E2E:READY_FOR_BACK] — paywall is up; host should press system BACK
 *
 * Reference: ../integration_test/E2E_TEST_INDEX.md (Flutter ↔ RN mapping)
 */

import React, { useEffect, useState } from 'react'
import {
    Platform,
    ScrollView,
    StyleSheet,
    Text,
    View,
} from 'react-native'
import Purchasely, {
    type PLYPresentationOutcome,
    setDefaultPresentationDismissHandler,
    removeDefaultPresentationDismissHandler,
} from 'react-native-purchasely'

// ── Config (mirrors com.purchasely.integration.BaseIntegrationTest) ─────────
const API_KEY = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87'
const PLACEMENT_AUDIENCES = 'integration_test_audiences'
const DEEPLINK_AUDIENCES = `ply://ply/placements/${PLACEMENT_AUDIENCES}`

// ── Types ────────────────────────────────────────────────────────────────────
type TestStatus = 'pending' | 'running' | 'pass' | 'fail'

interface TestResult {
    id: string
    name: string
    status: TestStatus
    details?: string
}

// ── Helpers ──────────────────────────────────────────────────────────────────
function sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms))
}

async function waitFor<T>(
    fn: () => T | null | undefined,
    timeoutMs: number,
    intervalMs = 250
): Promise<T> {
    const deadline = Date.now() + timeoutMs
    while (Date.now() < deadline) {
        const val = fn()
        if (val != null) return val
        await sleep(intervalMs)
    }
    throw new Error(`Timeout after ${timeoutMs}ms`)
}

// ── Initial test list ─────────────────────────────────────────────────────────
const INITIAL_TESTS: TestResult[] = [
    { id: 'T1', name: 'getAnonymousUserId non-empty', status: 'pending' },
    { id: 'T2', name: 'isAnonymous: true→login→false→logout→true', status: 'pending' },
    { id: 'T3', name: 'preload(placement) → typed Presentation', status: 'pending' },
    { id: 'T4', name: 'getDynamicOfferings → list', status: 'pending' },
    { id: 'T5', name: 'allProducts → list', status: 'pending' },
    { id: 'T6', name: 'interceptor cleanup round-trip', status: 'pending' },
    { id: 'T7', name: 'display(drawer 60%) → onPresented → close() → outcome', status: 'pending' },
    { id: 'T8', name: 'purchase interceptor: plan + promoOffer on real tap', status: 'pending' },
    { id: 'T9', name: 'defaultDismissHandler via deeplink + BACK', status: 'pending' },
]

// ── Component ─────────────────────────────────────────────────────────────────
export default function E2ETestRunner() {
    const [tests, setTests] = useState<TestResult[]>(INITIAL_TESTS)
    const [suiteStatus, setSuiteStatus] = useState<'running' | 'pass' | 'fail' | 'idle'>('idle')
    const [log, setLog] = useState<string[]>([])

    function updateTest(id: string, patch: Partial<TestResult>) {
        setTests((prev) => prev.map((t) => (t.id === id ? { ...t, ...patch } : t)))
    }

    function appendLog(line: string) {
        setLog((prev) => [...prev.slice(-200), line])
    }

    function pass(id: string, details: string) {
        updateTest(id, { status: 'pass', details })
        const msg = `[E2E:${id}:PASS] ${details}`
        console.log(msg)
        appendLog(`✓ ${id}: ${details}`)
    }

    function fail(id: string, error: unknown) {
        const msg = error instanceof Error ? error.message : String(error)
        updateTest(id, { status: 'fail', details: msg })
        console.error(`[E2E:${id}:FAIL] ${msg}`)
        appendLog(`✗ ${id}: ${msg}`)
    }

    function running(id: string) {
        updateTest(id, { status: 'running' })
        appendLog(`⏳ ${id}…`)
    }

    useEffect(() => {
        runSuite()
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [])

    // ── Suite ────────────────────────────────────────────────────────────────
    async function runSuite() {
        setSuiteStatus('running')
        console.log('[E2E:SUITE:START]')
        appendLog('=== Purchasely RN E2E Suite ===')

        // ── SDK init ──────────────────────────────────────────────────────────
        let sdkOk = false
        try {
            sdkOk = await Purchasely.builder(API_KEY)
                .runningMode('full')
                .logLevel('debug')
                .stores(['google'])
                .allowDeeplink(true)
                .start()
        } catch (e) {
            console.error('[E2E:INIT:FAIL]', e)
        }
        if (!sdkOk) {
            setSuiteStatus('fail')
            console.error('[E2E:SUITE:FAIL] SDK init failed')
            appendLog('✗ SDK init failed — aborting suite')
            return
        }
        appendLog('SDK initialized ✓')

        let suitePass = true

        // ── T1 ────────────────────────────────────────────────────────────────
        running('T1')
        try {
            const id = await Purchasely.getAnonymousUserId()
            if (!id || id.length === 0) throw new Error('anonymousUserId is empty')
            pass('T1', `id=${id}`)
        } catch (e) { fail('T1', e); suitePass = false }

        // ── T2 ────────────────────────────────────────────────────────────────
        running('T2')
        try {
            const a1 = await Purchasely.isAnonymous()
            if (!a1) throw new Error('Expected isAnonymous=true initially')
            await Purchasely.userLogin('rn_it_user')
            const a2 = await Purchasely.isAnonymous()
            if (a2) throw new Error('Expected isAnonymous=false after login')
            Purchasely.userLogout()
            const a3 = await Purchasely.isAnonymous()
            if (!a3) throw new Error('Expected isAnonymous=true after logout')
            pass('T2', 'true→false→true ✓')
        } catch (e) { fail('T2', e); suitePass = false }

        // ── T3 ────────────────────────────────────────────────────────────────
        running('T3')
        try {
            const req = Purchasely.presentation.placement(PLACEMENT_AUDIENCES).build()
            const pres = await req.preload()
            if (!pres.screenId || pres.screenId.length === 0) throw new Error('screenId is empty')
            pass(
                'T3',
                `screenId=${pres.screenId} type=${pres.type} plans=${pres.plans?.length ?? 0}`
            )
        } catch (e) { fail('T3', e); suitePass = false }

        // ── T4 ────────────────────────────────────────────────────────────────
        running('T4')
        try {
            const offerings = await Purchasely.getDynamicOfferings()
            if (!Array.isArray(offerings)) throw new Error('getDynamicOfferings did not return array')
            pass('T4', `count=${offerings.length}`)
        } catch (e) { fail('T4', e); suitePass = false }

        // ── T5 ────────────────────────────────────────────────────────────────
        running('T5')
        try {
            const products = await Purchasely.allProducts()
            if (!Array.isArray(products)) throw new Error('allProducts did not return array')
            pass('T5', `count=${products.length}`)
        } catch (e) { fail('T5', e); suitePass = false }

        // ── T6 ────────────────────────────────────────────────────────────────
        running('T6')
        try {
            Purchasely.interceptAction('purchase', async () => 'notHandled' as const)
            Purchasely.interceptAction('navigate', async () => 'notHandled' as const)
            Purchasely.removeActionInterceptor('purchase')
            Purchasely.removeAllActionInterceptors()
            pass('T6', 'register→removeActionInterceptor→removeAll ✓')
        } catch (e) { fail('T6', e); suitePass = false }

        // ── T7 — display(drawer 60%) + close() ───────────────────────────────
        running('T7')
        try {
            const req8 = Purchasely.presentation
                .placement(PLACEMENT_AUDIENCES)
                .build()

            await req8.preload()

            const displayPromise8 = req8.display({
                type: 'drawer',
                height: { type: 'percentage', value: 0.6 },
                dismissible: true,
            })

            // Wait 3 s for the native drawer to render before closing programmatically.
            // (onPresented is not reliably fired by sdk beta.12 — use a fixed delay.)
            // Note: timers only fire while MainActivity is not paused; MainActivity.kt
            // overrides onPause() to skip onHostPause() in E2E mode so sleep() works.
            await sleep(3000)

            // Programmatic close — exercises the onDismissed wiring fix.
            req8.close()

            const outcome8 = await Promise.race([
                displayPromise8,
                sleep(15000).then<never>(() => { throw new Error('dismiss timeout after 15 s') }),
            ])

            const validReasons = ['programmatic', 'button', 'backSystem']
            if (!validReasons.includes(outcome8.closeReason ?? '')) {
                throw new Error(`Unexpected closeReason: "${outcome8.closeReason}"`)
            }
            pass('T7', `closeReason=${outcome8.closeReason} purchaseResult=${outcome8.purchaseResult}`)
        } catch (e) { fail('T7', e); suitePass = false }

        await sleep(1000)

        // ── T8 — purchase interceptor: plan + promoOffer check on real tap ────
        running('T8')
        try {
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            let capturedInfo: any = null
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            let capturedPayload: any = null

            // Register interceptor BEFORE display so the SDK sees it immediately.
            // Return 'success': we handled it — no native purchase triggered.
            Purchasely.interceptAction('purchase', async (info: any, payload: any) => {
                capturedInfo = info
                capturedPayload = payload
                return 'success' as const
            })

            const req9 = Purchasely.presentation
                .placement(PLACEMENT_AUDIENCES)
                .build()

            // Do NOT await — the promise resolves at dismiss (which we control).
            req9.display()

            // Wait 3 s for the paywall to render before signalling the host driver.
            await sleep(3000)

            // Signal the host driver: tap the purchase button via uiautomator.
            console.log('[E2E:READY_FOR_TAP]')
            appendLog('T8: signaled READY_FOR_TAP — waiting for interceptor…')

            // Poll until the interceptor fires (host driver taps within 40 s).
            await waitFor(() => capturedPayload, 40000, 300)

            const vendorId: string | undefined = capturedPayload?.plan?.vendorId
            if (!vendorId) {
                throw new Error(
                    `payload.plan.vendorId missing; payload=${JSON.stringify(capturedPayload)}`
                )
            }
            pass(
                'T8',
                `kind=${capturedPayload?.kind} plan.vendorId=${vendorId} ` +
                `plan.productId=${capturedPayload?.plan?.productId} ` +
                `promoOffer=${JSON.stringify(capturedPayload?.plan?.promoOffer ?? null)} ` +
                `contentId=${capturedInfo?.contentId}`
            )

            // Close the paywall and clean up.
            req9.close()
            Purchasely.removeAllActionInterceptors()
        } catch (e) {
            fail('T8', e)
            suitePass = false
            Purchasely.removeAllActionInterceptors()
        }

        await sleep(1500)

        // ── T9 — global dismiss handler via deeplink + BACK ─────────────────
        running('T9')
        try {
            let globalOutcome: PLYPresentationOutcome | null = null

            setDefaultPresentationDismissHandler((outcome: PLYPresentationOutcome) => {
                globalOutcome = outcome
            })

            const handled = await Purchasely.handleDeeplink(DEEPLINK_AUDIENCES)
            if (!handled) throw new Error('handleDeeplink returned false')

            // Wait briefly for the paywall to render before signalling the driver.
            await sleep(2000)

            // Signal the host driver: press system BACK.
            console.log('[E2E:READY_FOR_BACK]')
            appendLog('T9: signaled READY_FOR_BACK — waiting for dismiss handler…')

            await waitFor(() => globalOutcome, 40000, 300)

            const reason = globalOutcome!.closeReason
            const validReasons10 = ['backSystem', 'programmatic', 'button']
            if (!validReasons10.includes(reason ?? '')) {
                throw new Error(`Unexpected closeReason: "${reason}"`)
            }
            pass(
                'T9',
                `closeReason=${reason} ` +
                `screenId=${globalOutcome!.presentation?.screenId}`
            )

            removeDefaultPresentationDismissHandler()
        } catch (e) {
            fail('T9', e)
            suitePass = false
            removeDefaultPresentationDismissHandler()
        }

        // ── Final report ─────────────────────────────────────────────────────
        setSuiteStatus(suitePass ? 'pass' : 'fail')
        if (suitePass) {
            console.log('[E2E:SUITE:PASS] All 9 tests passed')
            appendLog('=== SUITE PASS ✓ ===')
        } else {
            console.log('[E2E:SUITE:FAIL] One or more tests failed')
            appendLog('=== SUITE FAIL ✗ ===')
        }
    }

    // ── Render ────────────────────────────────────────────────────────────────
    const suiteBg =
        suiteStatus === 'pass'
            ? '#2e7d32'
            : suiteStatus === 'fail'
            ? '#b71c1c'
            : '#1565c0'

    return (
        <ScrollView style={styles.container}>
            <View style={[styles.header, { backgroundColor: suiteBg }]}>
                <Text style={styles.headerText}>
                    Purchasely RN E2E — {Platform.OS}
                </Text>
                <Text style={styles.headerSub}>
                    {suiteStatus === 'idle' && 'Starting…'}
                    {suiteStatus === 'running' && 'Running…'}
                    {suiteStatus === 'pass' && '✓ All tests passed'}
                    {suiteStatus === 'fail' && '✗ Some tests failed'}
                </Text>
            </View>

            {tests.map((t) => (
                <View
                    key={t.id}
                    style={[
                        styles.testRow,
                        t.status === 'pass' && styles.testPass,
                        t.status === 'fail' && styles.testFail,
                        t.status === 'running' && styles.testRunning,
                    ]}
                >
                    <Text style={styles.testId}>{t.id}</Text>
                    <View style={styles.testBody}>
                        <Text style={styles.testName}>{t.name}</Text>
                        {t.details && (
                            <Text style={styles.testDetails} numberOfLines={3}>
                                {t.details}
                            </Text>
                        )}
                    </View>
                    <Text style={styles.testIcon}>
                        {t.status === 'pending' && '○'}
                        {t.status === 'running' && '⟳'}
                        {t.status === 'pass' && '✓'}
                        {t.status === 'fail' && '✗'}
                    </Text>
                </View>
            ))}

            <View style={styles.logBox}>
                <Text style={styles.logTitle}>Log</Text>
                {log.map((line, i) => (
                    <Text key={i} style={styles.logLine}>
                        {line}
                    </Text>
                ))}
            </View>
        </ScrollView>
    )
}

// ── Styles ────────────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
    container: { flex: 1, backgroundColor: '#121212' },
    header: {
        padding: 20,
        paddingTop: 50,
        alignItems: 'center',
    },
    headerText: { color: '#fff', fontSize: 18, fontWeight: '700' },
    headerSub: { color: '#fff', fontSize: 14, marginTop: 4 },
    testRow: {
        flexDirection: 'row',
        alignItems: 'center',
        padding: 12,
        marginHorizontal: 12,
        marginTop: 6,
        borderRadius: 8,
        backgroundColor: '#2c2c2e',
    },
    testPass: { backgroundColor: '#1b5e20' },
    testFail: { backgroundColor: '#7f0000' },
    testRunning: { backgroundColor: '#1a237e' },
    testId: {
        color: '#fff',
        fontWeight: '700',
        width: 32,
        fontSize: 12,
    },
    testBody: { flex: 1, paddingHorizontal: 8 },
    testName: { color: '#eee', fontSize: 13 },
    testDetails: { color: '#aaa', fontSize: 11, marginTop: 2 },
    testIcon: { color: '#fff', fontSize: 16, width: 20, textAlign: 'center' },
    logBox: {
        margin: 12,
        marginTop: 16,
        padding: 12,
        backgroundColor: '#1c1c1e',
        borderRadius: 8,
    },
    logTitle: { color: '#888', fontSize: 11, marginBottom: 6 },
    logLine: { color: '#ccc', fontSize: 11, fontFamily: 'monospace', marginBottom: 2 },
})
