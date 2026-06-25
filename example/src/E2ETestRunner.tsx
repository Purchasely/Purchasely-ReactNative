/**
 * E2E test runner — T1–T13
 *
 * Renders as the root component when the app is launched with E2E_MODE=true.
 * Each test runs sequentially in a single SDK session.
 *
 * Host-driven tests (require an external driver process):
 *   T8: [E2E:READY_FOR_TAP]  — paywall displayed; host taps the purchase button
 *   T9: [E2E:READY_FOR_BACK] — paywall displayed; host dismisses it
 *                              Android: adb keyevent BACK via uiautomator
 *                              iOS:     xcrun simctl io booted swipe (prepared, not yet active)
 *
 * Host scripts:
 *   Android: integration_test/run_e2e.sh  (android-emulator-runner + uiautomator)
 *   iOS:     integration_test/run_e2e_ios.sh (prepared, not yet in CI)
 *
 * Reference: integration_test/E2E_TEST_INDEX.md
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
    PLYPresentationType,
    type PLYPresentationOutcome,
    setDefaultPresentationDismissHandler,
    removeDefaultPresentationDismissHandler,
} from 'react-native-purchasely'

// ── Config ───────────────────────────────────────────────────────────────────
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
    { id: 'T1',  name: 'getAnonymousUserId — non-empty + UUID format', status: 'pending' },
    { id: 'T2',  name: 'isAnonymous: true→login→false→logout→true', status: 'pending' },
    { id: 'T3',  name: 'preload → placementId + type + audienceId + plans[].planVendorId', status: 'pending' },
    { id: 'T4',  name: 'getDynamicOfferings → array', status: 'pending' },
    { id: 'T5',  name: 'allProducts → array', status: 'pending' },
    { id: 'T6',  name: 'interceptor register → removeOne → removeAll (no error)', status: 'pending' },
    { id: 'T7',  name: 'display(drawer 60%) → close() → outcome: closeReason + presentation props', status: 'pending' },
    { id: 'T8',  name: 'purchase interceptor on real tap: plan.vendorId + offer', status: 'pending' },
    { id: 'T9',  name: 'defaultDismissHandler + deeplink + BACK → outcome.presentation props', status: 'pending' },
    { id: 'T10', name: 'addEventListener → PRESENTATION_VIEWED: placement_id + sdk_version', status: 'pending' },
    { id: 'T11', name: 'PRESENTATION_CLOSED → placement_id + displayed_presentation', status: 'pending' },
    { id: 'T12', name: 'programmatic close does NOT fire close/closeAll interceptor', status: 'pending' },
    { id: 'T13', name: 'user attributes: set/get string + number + boolean + clear', status: 'pending' },
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

    // ── Suite ─────────────────────────────────────────────────────────────────
    async function runSuite() {
        setSuiteStatus('running')
        console.log('[E2E:SUITE:START]')
        appendLog('=== Purchasely RN E2E Suite ===')

        // ── SDK init ──────────────────────────────────────────────────────────
        let sdkOk = false
        try {
            // stores() is Android-only; storekitVersion() is iOS-only
            const b = Purchasely.builder(API_KEY)
                .runningMode('full')
                .logLevel('debug')
                .allowDeeplink(true)
            sdkOk = await (
                Platform.OS === 'android'
                    ? b.stores(['google'])
                    : b.storekitVersion('storeKit2')
            ).start()
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

        // ── T1 — anonymous user ID ────────────────────────────────────────────
        running('T1')
        try {
            const id = await Purchasely.getAnonymousUserId()
            if (!id || id.length === 0) throw new Error('anonymousUserId is empty')
            const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
            if (!uuidRegex.test(id)) throw new Error(`anonymousUserId not UUID format: ${id}`)
            pass('T1', `id=${id}`)
        } catch (e) { fail('T1', e); suitePass = false }

        // ── T2 — login / logout cycle ─────────────────────────────────────────
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

        // ── T3 — preload: presentation properties ─────────────────────────────
        running('T3')
        try {
            const req = Purchasely.presentation.placement(PLACEMENT_AUDIENCES).build()
            const pres = await req.preload()

            if (!pres.screenId || pres.screenId.length === 0) throw new Error('screenId is empty')
            if (!pres.placementId) throw new Error('placementId is missing')
            if (pres.placementId !== PLACEMENT_AUDIENCES) {
                throw new Error(`placementId mismatch: expected "${PLACEMENT_AUDIENCES}", got "${pres.placementId}"`)
            }

            // Type must be NORMAL (active placement) or FALLBACK (network issue — still valid)
            const validTypes = [PLYPresentationType.NORMAL, PLYPresentationType.FALLBACK]
            if (pres.type != null && !validTypes.includes(pres.type)) {
                throw new Error(`Unexpected type: ${pres.type} (expected NORMAL or FALLBACK)`)
            }

            if (!Array.isArray(pres.plans) || pres.plans.length === 0) {
                throw new Error('plans array is empty or missing')
            }
            const firstPlan = pres.plans[0]
            if (!firstPlan?.planVendorId) {
                throw new Error(`plans[0].planVendorId missing; plan=${JSON.stringify(firstPlan)}`)
            }

            pass(
                'T3',
                `screenId=${pres.screenId} placementId=${pres.placementId} ` +
                `type=${pres.type} audienceId=${pres.audienceId ?? 'null'} ` +
                `plans=${pres.plans.length} plan[0].planVendorId=${firstPlan.planVendorId}`
            )
        } catch (e) { fail('T3', e); suitePass = false }

        // ── T4 — dynamic offerings ────────────────────────────────────────────
        running('T4')
        try {
            const offerings = await Purchasely.getDynamicOfferings()
            if (!Array.isArray(offerings)) throw new Error('getDynamicOfferings did not return array')
            pass('T4', `count=${offerings.length}`)
        } catch (e) { fail('T4', e); suitePass = false }

        // ── T5 — all products ─────────────────────────────────────────────────
        running('T5')
        try {
            const products = await Purchasely.allProducts()
            if (!Array.isArray(products)) throw new Error('allProducts did not return array')
            pass('T5', `count=${products.length}`)
        } catch (e) { fail('T5', e); suitePass = false }

        // ── T6 — interceptor cleanup round-trip ───────────────────────────────
        running('T6')
        try {
            Purchasely.interceptAction('purchase', async () => 'notHandled' as const)
            Purchasely.interceptAction('navigate', async () => 'notHandled' as const)
            Purchasely.removeActionInterceptor('purchase')
            Purchasely.removeAllActionInterceptors()
            pass('T6', 'register→removeActionInterceptor→removeAll ✓')
        } catch (e) { fail('T6', e); suitePass = false }

        // ── T7 — display(drawer 60%) + close() → outcome properties ──────────
        running('T7')
        try {
            const req7 = Purchasely.presentation
                .placement(PLACEMENT_AUDIENCES)
                .build()

            await req7.preload()

            const displayPromise7 = req7.display({
                type: 'drawer',
                height: { type: 'percentage', value: 0.6 },
                dismissible: true,
            })

            // Wait 3 s for the drawer to render before programmatic close.
            await sleep(3000)
            req7.close()

            const outcome7 = await Promise.race([
                displayPromise7,
                sleep(15000).then<never>(() => { throw new Error('dismiss timeout after 15 s') }),
            ])

            const validReasons = ['programmatic', 'button', 'backSystem']
            if (!validReasons.includes(outcome7.closeReason ?? '')) {
                throw new Error(`Unexpected closeReason: "${outcome7.closeReason}"`)
            }
            if (!outcome7.presentation?.screenId) {
                throw new Error(`outcome.presentation.screenId missing; presentation=${JSON.stringify(outcome7.presentation)}`)
            }
            if (!outcome7.presentation?.placementId) {
                throw new Error(`outcome.presentation.placementId missing`)
            }

            pass(
                'T7',
                `closeReason=${outcome7.closeReason} ` +
                `presentation.screenId=${outcome7.presentation.screenId} ` +
                `presentation.placementId=${outcome7.presentation.placementId}`
            )
        } catch (e) { fail('T7', e); suitePass = false }

        await sleep(1000)

        // ── T8 — purchase interceptor: plan + offer on real tap ───────────────
        running('T8')
        try {
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            let capturedInfo: any = null
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            let capturedPayload: any = null

            // Return 'success': we handled it — no native purchase triggered.
            Purchasely.interceptAction('purchase', async (info: any, payload: any) => {
                capturedInfo = info
                capturedPayload = payload
                return 'success' as const
            })

            const req8 = Purchasely.presentation
                .placement(PLACEMENT_AUDIENCES)
                .build()

            req8.display()

            // Wait 3 s for the paywall to render before signalling the host driver.
            await sleep(3000)
            console.log('[E2E:READY_FOR_TAP]')
            appendLog('T8: signaled READY_FOR_TAP — waiting for interceptor…')

            await waitFor(() => capturedPayload, 40000, 300)

            const vendorId: string | undefined = capturedPayload?.plan?.vendorId
            if (!vendorId) {
                throw new Error(
                    `payload.plan.vendorId missing; payload=${JSON.stringify(capturedPayload)}`
                )
            }

            // offer is the promo offer attached to the purchase action (may be null)
            const offer = capturedPayload?.offer ?? null

            pass(
                'T8',
                `kind=${capturedPayload?.kind} plan.vendorId=${vendorId} ` +
                `plan.storeProductId=${capturedPayload?.plan?.storeProductId ?? 'n/a'} ` +
                `offer=${offer != null ? JSON.stringify(offer) : 'none'} ` +
                `contentId=${capturedInfo?.contentId ?? 'none'}`
            )

            req8.close()
            Purchasely.removeAllActionInterceptors()
        } catch (e) {
            fail('T8', e)
            suitePass = false
            Purchasely.removeAllActionInterceptors()
        }

        await sleep(1500)

        // ── T9 — defaultDismissHandler + deeplink + BACK → outcome props ──────
        running('T9')
        try {
            let globalOutcome: PLYPresentationOutcome | null = null

            setDefaultPresentationDismissHandler((outcome: PLYPresentationOutcome) => {
                globalOutcome = outcome
            })

            const handled = await Purchasely.handleDeeplink(DEEPLINK_AUDIENCES)
            if (!handled) throw new Error('handleDeeplink returned false')

            await sleep(2000)
            console.log('[E2E:READY_FOR_BACK]')
            appendLog('T9: signaled READY_FOR_BACK — waiting for dismiss handler…')

            await waitFor(() => globalOutcome, 40000, 300)

            const reason = globalOutcome!.closeReason
            const validReasons9 = ['backSystem', 'programmatic', 'button']
            if (!validReasons9.includes(reason ?? '')) {
                throw new Error(`Unexpected closeReason: "${reason}"`)
            }
            if (!globalOutcome!.presentation?.screenId) {
                throw new Error(`outcome.presentation.screenId missing`)
            }
            if (!globalOutcome!.presentation?.placementId) {
                throw new Error(`outcome.presentation.placementId missing`)
            }

            pass(
                'T9',
                `closeReason=${reason} ` +
                `presentation.screenId=${globalOutcome!.presentation?.screenId} ` +
                `presentation.placementId=${globalOutcome!.presentation?.placementId}`
            )

            removeDefaultPresentationDismissHandler()
        } catch (e) {
            fail('T9', e)
            suitePass = false
            removeDefaultPresentationDismissHandler()
        }

        await sleep(1000)

        // ── T10 — addEventListener → PRESENTATION_VIEWED ──────────────────────
        running('T10')
        try {
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            let viewedEvent: any = null
            const listener10 = Purchasely.addEventListener((event: any) => {
                if (event.name === 'PRESENTATION_VIEWED') viewedEvent = event
            })

            const req10 = Purchasely.presentation.placement(PLACEMENT_AUDIENCES).build()
            req10.display()

            await waitFor(() => viewedEvent, 15000, 300)

            const placementId10 = viewedEvent.properties?.placement_id
            const sdkVersion10 = viewedEvent.properties?.sdk_version
            if (!placementId10) {
                throw new Error(`PRESENTATION_VIEWED missing placement_id; props=${JSON.stringify(viewedEvent.properties)}`)
            }
            if (!sdkVersion10) {
                throw new Error('PRESENTATION_VIEWED missing sdk_version')
            }

            pass(
                'T10',
                `PRESENTATION_VIEWED: placement_id=${placementId10} ` +
                `sdk_version=${sdkVersion10} ` +
                `audience_id=${viewedEvent.properties?.audience_id ?? 'null'}`
            )

            req10.close()
            await sleep(500)
            listener10.remove()
        } catch (e) { fail('T10', e); suitePass = false }

        await sleep(500)

        // ── T11 — PRESENTATION_CLOSED → placement_id + displayed_presentation ─
        running('T11')
        try {
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            let viewedEvent11: any = null
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            let closedEvent11: any = null
            const listener11 = Purchasely.addEventListener((event: any) => {
                if (event.name === 'PRESENTATION_VIEWED') viewedEvent11 = event
                if (event.name === 'PRESENTATION_CLOSED') closedEvent11 = event
            })

            const req11 = Purchasely.presentation.placement(PLACEMENT_AUDIENCES).build()
            req11.display()

            // Wait for presentation to appear before closing
            await waitFor(() => viewedEvent11, 15000, 300)
            await sleep(500)

            req11.close()

            await waitFor(() => closedEvent11, 10000, 300)

            const placementId11 = closedEvent11.properties?.placement_id
            const displayedPres11 = closedEvent11.properties?.displayed_presentation
            if (!placementId11) {
                throw new Error(`PRESENTATION_CLOSED missing placement_id; props=${JSON.stringify(closedEvent11.properties)}`)
            }
            if (!displayedPres11) {
                throw new Error('PRESENTATION_CLOSED missing displayed_presentation')
            }

            pass(
                'T11',
                `PRESENTATION_CLOSED: placement_id=${placementId11} ` +
                `displayed_presentation=${displayedPres11}`
            )

            listener11.remove()
        } catch (e) { fail('T11', e); suitePass = false }

        await sleep(500)

        // ── T12 — programmatic close does NOT trigger close/closeAll interceptor
        running('T12')
        try {
            let interceptorCalled = false

            Purchasely.interceptAction('close', async () => {
                interceptorCalled = true
                return 'notHandled' as const
            })
            Purchasely.interceptAction('closeAll', async () => {
                interceptorCalled = true
                return 'notHandled' as const
            })

            const req12 = Purchasely.presentation.placement(PLACEMENT_AUDIENCES).build()
            req12.display()
            await sleep(3000)

            // req.close() is programmatic — must bypass the interceptor
            req12.close()
            await sleep(2000)

            Purchasely.removeAllActionInterceptors()

            if (interceptorCalled) {
                throw new Error('close/closeAll interceptor was triggered on programmatic close — unexpected')
            }
            pass('T12', 'close/closeAll interceptors NOT triggered by req.close() ✓')
        } catch (e) {
            fail('T12', e)
            suitePass = false
            Purchasely.removeAllActionInterceptors()
        }

        // ── T13 — user attributes: set / get / clear ──────────────────────────
        running('T13')
        try {
            Purchasely.setUserAttributeWithString('e2e_str', 'hello_rn')
            Purchasely.setUserAttributeWithNumber('e2e_num', 42)
            Purchasely.setUserAttributeWithBoolean('e2e_bool', true)

            await sleep(300) // let native bridge process the set calls

            const strVal = await Purchasely.userAttribute('e2e_str')
            const numVal = await Purchasely.userAttribute('e2e_num')
            const boolVal = await Purchasely.userAttribute('e2e_bool')

            if (strVal !== 'hello_rn') throw new Error(`str: expected 'hello_rn', got ${JSON.stringify(strVal)}`)
            if (numVal !== 42) throw new Error(`num: expected 42, got ${JSON.stringify(numVal)}`)
            if (boolVal !== true) throw new Error(`bool: expected true, got ${JSON.stringify(boolVal)}`)

            // Clear and verify
            Purchasely.clearUserAttribute('e2e_str')
            Purchasely.clearUserAttribute('e2e_num')
            Purchasely.clearUserAttribute('e2e_bool')

            await sleep(300)

            const strAfter = await Purchasely.userAttribute('e2e_str')
            const numAfter = await Purchasely.userAttribute('e2e_num')
            if (strAfter != null) throw new Error(`e2e_str not cleared, got ${JSON.stringify(strAfter)}`)
            if (numAfter != null) throw new Error(`e2e_num not cleared, got ${JSON.stringify(numAfter)}`)

            pass('T13', `set: str=hello_rn num=42 bool=true → cleared → null ✓`)
        } catch (e) {
            fail('T13', e)
            suitePass = false
            Purchasely.clearUserAttributes()
        }

        // ── Final report ──────────────────────────────────────────────────────
        setSuiteStatus(suitePass ? 'pass' : 'fail')
        if (suitePass) {
            console.log('[E2E:SUITE:PASS] All 13 tests passed')
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
        width: 36,
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
