/**
 * E2E test runner — T1–T27
 *
 * Renders as the root component when the app is launched with E2E_MODE=true.
 * The main suite (T1–T26) runs sequentially in a single SDK session; T27
 * (cold-start deeplink) needs a fresh process and runs as a dedicated phase.
 *
 * Phase routing (Android only): `MainActivity` forwards the `E2E_PHASE` intent
 * extra as a `phase` initial prop. When `phase === 'deeplink_coldstart'` the
 * runner runs ONLY the T27 cold-start flow (init builder chains
 * `.handleDeeplink()` BEFORE `start()`). iOS `AppDelegate` forwards only
 * `e2eMode` (no phase bridge), so T27 is skipped on iOS.
 *
 * Host-driven tests (require an external driver process):
 *   T8: [E2E:READY_FOR_TAP]  — paywall displayed; host taps the purchase button
 *   T9: [E2E:READY_FOR_BACK] — paywall displayed; host dismisses it
 *                              Android: adb keyevent BACK via uiautomator
 *                              iOS:     xcrun simctl io booted swipe (prepared, not yet active)
 *
 * T21–T27 are all driver-free (programmatic close / analytics events); only
 * T27 requires the dedicated cold-start phase launch (Android).
 *
 * Host scripts:
 *   Android: integration_test/run_e2e.sh  (android-emulator-runner + uiautomator)
 *   iOS:     integration_test/run_e2e_ios.sh
 *
 * Reference: integration_test/E2E_TEST_INDEX.md
 */

import React, { useEffect, useRef, useState } from 'react'
import {
    Platform,
    ScrollView,
    StyleSheet,
    Text,
    View,
} from 'react-native'
import Purchasely, {
    LogLevels,
    PLYDataProcessingPurpose,
    PLYPresentationType,
    PLYThemeMode,
    PLYPresentationView,
    type PLYPresentationOutcome,
    type PLYPresentationRequest,
    type PLYPresentationViewResult,
    setDefaultPresentationDismissHandler,
    removeDefaultPresentationDismissHandler,
} from 'react-native-purchasely'

// ── Config ───────────────────────────────────────────────────────────────────
const API_KEY = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87'
const PLACEMENT_AUDIENCES = 'integration_test_audiences'
const DEEPLINK_AUDIENCES = `ply://ply/placements/${PLACEMENT_AUDIENCES}`

// Dedicated phase (Android): launched by run_e2e.sh with
// `am start … --es E2E_PHASE deeplink_coldstart` in a fresh process so the
// start builder can chain `.handleDeeplink()` BEFORE `start()` (see T27).
const COLDSTART_PHASE = 'deeplink_coldstart'

// ── Types ────────────────────────────────────────────────────────────────────
type TestStatus = 'pending' | 'running' | 'pass' | 'fail' | 'skip'

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
    { id: 'T14', name: 'user attributes: double + date + arrays', status: 'pending' },
    { id: 'T15', name: 'user attributes: bulk map + clear + clear built-ins', status: 'pending' },
    { id: 'T16', name: 'user attributes: increment + decrement', status: 'pending' },
    { id: 'T17', name: 'catalog lookup: product + plan + intro eligibility', status: 'pending' },
    { id: 'T18', name: 'dynamic offerings: set/get/remove/clear', status: 'pending' },
    { id: 'T19', name: 'presentation.screen(id) + modal/popin transitions', status: 'pending' },
    { id: 'T20', name: 'config setters smoke test', status: 'pending' },
    { id: 'T21', name: 'synchronize() resolves OR rejects cleanly (no hang)', status: 'pending' },
    { id: 'T22', name: 'default dismiss handler catches fire-and-forget display()', status: 'pending' },
    { id: 'T23', name: 'local onDismissed wins over the default handler', status: 'pending' },
    { id: 'T24', name: 'user attribute listener: set + removed events', status: 'pending' },
    { id: 'T25', name: 'embedded <PLYPresentationView request={…}> renders', status: 'pending' },
    { id: 'T26', name: 'PLYLoadedPresentation lifecycle: display/close → outcome', status: 'pending' },
    { id: 'T27', name: 'cold-start deeplink via builder .handleDeeplink() before start()', status: 'pending' },
]

// ── Component ─────────────────────────────────────────────────────────────────
export default function E2ETestRunner(props: { phase?: string } = {}) {
    // Android forwards the E2E_PHASE intent extra as `phase`; iOS/default => 'all'.
    const phase = props.phase ?? 'all'
    const [tests, setTests] = useState<TestResult[]>(INITIAL_TESTS)
    const [suiteStatus, setSuiteStatus] = useState<'running' | 'pass' | 'fail' | 'idle'>('idle')
    const [log, setLog] = useState<string[]>([])
    // T25: the embedded paywall request whose native view is currently mounted.
    const [inlineRequest, setInlineRequest] = useState<PLYPresentationRequest | null>(null)
    // T25: last result delivered to the embedded view's onPresentationClosed.
    const inlineClosedRef = useRef<PLYPresentationViewResult | null>(null)

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

    function skip(id: string, reason: string) {
        updateTest(id, { status: 'skip', details: reason })
        console.log(`[E2E:${id}:SKIP] ${reason}`)
        appendLog(`⊘ ${id}: ${reason}`)
    }

    useEffect(() => {
        if (phase === COLDSTART_PHASE) {
            runColdStartPhase()
        } else {
            runSuite()
        }
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
            await Purchasely.setCustomScreenProvider({
                componentName: 'PurchaselyCustomScreen',
            })
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

            // Programmatic close → closeReason MUST be exactly 'programmatic'
            // (pinned, not merely "one of the valid reasons"), and since no
            // purchase happened the outcome's purchaseResult MUST be 'cancelled'.
            // This locks the v6 string-union contract on both platforms.
            if (outcome7.closeReason !== 'programmatic') {
                throw new Error(`closeReason expected 'programmatic', got "${outcome7.closeReason}"`)
            }
            if (outcome7.purchaseResult !== 'cancelled') {
                throw new Error(`purchaseResult expected 'cancelled', got "${outcome7.purchaseResult}"`)
            }
            if (!outcome7.presentation?.screenId) {
                throw new Error(`outcome.presentation.screenId missing; presentation=${JSON.stringify(outcome7.presentation)}`)
            }
            if (!outcome7.presentation?.placementId) {
                throw new Error(`outcome.presentation.placementId missing`)
            }

            pass(
                'T7',
                `closeReason=${outcome7.closeReason} purchaseResult=${outcome7.purchaseResult} ` +
                `presentation.screenId=${outcome7.presentation.screenId} ` +
                `presentation.placementId=${outcome7.presentation.placementId}`
            )
        } catch (e) { fail('T7', e); suitePass = false }

        await sleep(1000)

        // ── T8 — purchase interceptor: plan + offer on real tap ───────────────
        running('T8')
        let req8: PLYPresentationRequest | null = null
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

            req8 = Purchasely.presentation
                .placement(PLACEMENT_AUDIENCES)
                .build()

            req8.display()

            // Wait 3 s for the paywall to render before signalling the host driver.
            await sleep(3000)
            console.log('[E2E:READY_FOR_TAP]')
            appendLog('T8: signaled READY_FOR_TAP — waiting for interceptor…')

            // The iOS host driver polls the accessibility tree for up to 90 s,
            // so its deadline must remain within this wait window.
            await waitFor(() => capturedPayload, 100000, 300)

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
            req8?.close()
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

            // The iOS host driver polls for up to 60 s before dismissing.
            await waitFor(() => globalOutcome, 70000, 300)

            // Dismissed via system back (Android BACK key / iOS swipe-down) →
            // closeReason MUST be exactly 'backSystem' on both platforms.
            const reason = globalOutcome!.closeReason
            if (reason !== 'backSystem') {
                throw new Error(`closeReason expected 'backSystem', got "${reason}"`)
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

        // ── T14 — extended user attribute types ───────────────────────────────
        running('T14')
        try {
            Purchasely.setUserAttributeWithDouble('e2e_dbl', 3.14)
            Purchasely.setUserAttributeWithDate('e2e_date', new Date('2024-06-15T12:00:00.000Z'))
            Purchasely.setUserAttributeWithStringArray('e2e_str_arr', ['alpha', 'beta', 'gamma'])
            Purchasely.setUserAttributeWithIntArray('e2e_int_arr', [10, 20, 30])
            Purchasely.setUserAttributeWithBooleanArray('e2e_bool_arr', [true, false, true])

            await sleep(400)

            const rawDbl = await Purchasely.userAttribute('e2e_dbl')
            if (typeof rawDbl !== 'number' || Math.abs(rawDbl - 3.14) > 0.01) {
                throw new Error(`e2e_dbl expected ~3.14, got ${JSON.stringify(rawDbl)}`)
            }

            const dateVal = await Purchasely.userAttribute('e2e_date')
            const date = typeof dateVal === 'string' ? new Date(dateVal) : null
            if (!date || Number.isNaN(date.getTime())) {
                throw new Error(`e2e_date expected ISO date string, got ${JSON.stringify(dateVal)}`)
            }
            if (date.getUTCFullYear() !== 2024 || date.getUTCMonth() !== 5 || date.getUTCDate() !== 15) {
                throw new Error(`e2e_date expected 2024-06-15, got ${date.toISOString()}`)
            }

            const strArr = await Purchasely.userAttribute('e2e_str_arr')
            const intArr = await Purchasely.userAttribute('e2e_int_arr')
            const boolArr = await Purchasely.userAttribute('e2e_bool_arr')
            if (!Array.isArray(strArr) || strArr.length !== 3) throw new Error(`e2e_str_arr invalid: ${JSON.stringify(strArr)}`)
            if (!Array.isArray(intArr) || intArr.length !== 3) throw new Error(`e2e_int_arr invalid: ${JSON.stringify(intArr)}`)
            if (!Array.isArray(boolArr) || boolArr.length !== 3) throw new Error(`e2e_bool_arr invalid: ${JSON.stringify(boolArr)}`)

            for (const key of ['e2e_dbl', 'e2e_date', 'e2e_str_arr', 'e2e_int_arr', 'e2e_bool_arr']) {
                Purchasely.clearUserAttribute(key)
            }

            pass('T14', `dbl=${rawDbl} date=${date.toISOString()} arrays=3/3/3 ✓`)
        } catch (e) {
            fail('T14', e)
            suitePass = false
            for (const key of ['e2e_dbl', 'e2e_date', 'e2e_str_arr', 'e2e_int_arr', 'e2e_bool_arr']) {
                Purchasely.clearUserAttribute(key)
            }
        }

        // ── T15 — user attributes bulk operations ─────────────────────────────
        running('T15')
        try {
            Purchasely.setUserAttributeWithString('bulk_a', 'hello')
            Purchasely.setUserAttributeWithInt('bulk_b', 99)
            await sleep(300)

            const all = await Purchasely.userAttributes()
            if (!all || typeof all !== 'object' || Array.isArray(all)) {
                throw new Error(`userAttributes expected object map, got ${JSON.stringify(all)}`)
            }
            if (all.bulk_a !== 'hello') {
                throw new Error(`bulk_a expected 'hello', got ${JSON.stringify(all.bulk_a)}`)
            }

            Purchasely.clearUserAttributes()
            await sleep(300)

            const afterClear = await Purchasely.userAttribute('bulk_a')
            if (afterClear != null) {
                throw new Error(`bulk_a not cleared, got ${JSON.stringify(afterClear)}`)
            }

            Purchasely.clearBuiltInAttributes()
            pass('T15', `userAttributes=${Object.keys(all).length} entries → clearUserAttributes + clearBuiltInAttributes ✓`)
        } catch (e) {
            fail('T15', e)
            suitePass = false
            Purchasely.clearUserAttributes()
        }

        // ── T16 — increment / decrement ───────────────────────────────────────
        running('T16')
        try {
            Purchasely.clearUserAttribute('e2e_counter')
            await sleep(300)

            Purchasely.incrementUserAttribute({ key: 'e2e_counter', value: 7 })
            await sleep(300)
            const v1 = await Purchasely.userAttribute('e2e_counter')
            if (typeof v1 !== 'number') throw new Error(`v1 expected number, got ${JSON.stringify(v1)}`)

            Purchasely.incrementUserAttribute({ key: 'e2e_counter', value: 3 })
            await sleep(300)
            const v2 = await Purchasely.userAttribute('e2e_counter')
            if (typeof v2 !== 'number' || v2 <= v1) {
                throw new Error(`increment did not increase counter: v1=${JSON.stringify(v1)} v2=${JSON.stringify(v2)}`)
            }

            Purchasely.decrementUserAttribute({ key: 'e2e_counter', value: 4 })
            await sleep(300)
            const v3 = await Purchasely.userAttribute('e2e_counter')
            if (typeof v3 !== 'number' || v3 >= v2) {
                throw new Error(`decrement did not decrease counter: v2=${JSON.stringify(v2)} v3=${JSON.stringify(v3)}`)
            }

            Purchasely.clearUserAttribute('e2e_counter')
            pass('T16', `counter: ${v1} → ${v2} → ${v3} ✓`)
        } catch (e) {
            fail('T16', e)
            suitePass = false
            Purchasely.clearUserAttribute('e2e_counter')
        }

        // ── T17 — product / plan lookup + intro eligibility ──────────────────
        running('T17')
        try {
            const products = await Purchasely.allProducts()
            if (!Array.isArray(products) || products.length === 0) {
                throw new Error('allProducts returned no products')
            }

            const product = products[0]
            const fetchedProduct = await Purchasely.productWithIdentifier(product.vendorId)
            if (fetchedProduct.vendorId !== product.vendorId) {
                throw new Error(`productWithIdentifier mismatch: ${fetchedProduct.vendorId} !== ${product.vendorId}`)
            }
            if (!fetchedProduct.name) throw new Error('productWithIdentifier returned empty name')

            const plan = product.plans?.[0]
            if (!plan?.vendorId) throw new Error('first product has no plan.vendorId')

            const fetchedPlan = await Purchasely.planWithIdentifier(plan.vendorId)
            if (!fetchedPlan || fetchedPlan.vendorId !== plan.vendorId) {
                throw new Error(`planWithIdentifier mismatch: ${fetchedPlan?.vendorId} !== ${plan.vendorId}`)
            }

            const isEligible = await Purchasely.isEligibleForIntroOffer(plan.vendorId)
            if (typeof isEligible !== 'boolean') throw new Error(`intro eligibility expected boolean, got ${JSON.stringify(isEligible)}`)

            pass('T17', `product=${fetchedProduct.vendorId} plan=${fetchedPlan.vendorId} introEligible=${isEligible}`)
        } catch (e) { fail('T17', e); suitePass = false }

        // ── T18 — dynamic offerings CRUD ──────────────────────────────────────
        running('T18')
        try {
            const presentation = await Purchasely.presentation
                .placement(PLACEMENT_AUDIENCES)
                .build()
                .preload()
            const planVendorId = presentation.plans?.[0]?.planVendorId
            if (!planVendorId) throw new Error('presentation has no planVendorId for dynamic offering')

            const ok = await Purchasely.setDynamicOffering({
                reference: 'e2e_ref',
                planVendorId,
                offerVendorId: null,
            })
            if (typeof ok !== 'boolean') throw new Error(`setDynamicOffering expected boolean, got ${JSON.stringify(ok)}`)

            await sleep(300)
            const offerings = await Purchasely.getDynamicOfferings()
            if (!Array.isArray(offerings)) throw new Error('getDynamicOfferings did not return array')

            Purchasely.removeDynamicOffering('e2e_ref')
            await sleep(300)
            Purchasely.clearDynamicOfferings()

            pass('T18', `setDynamicOffering=${ok} offerings=${offerings.length} remove+clear ✓`)
        } catch (e) {
            fail('T18', e)
            suitePass = false
            Purchasely.clearDynamicOfferings()
        }

        // ── T19 — screen(id) + modal / popin transitions ──────────────────────
        running('T19')
        try {
            const byPlacement = await Purchasely.presentation
                .placement(PLACEMENT_AUDIENCES)
                .build()
                .preload()
            const screenId = byPlacement.screenId
            if (!screenId) throw new Error('preloaded placement has no screenId')

            const modalReq = Purchasely.presentation.screen(screenId).build()
            const modalPresentation = await modalReq.preload()
            if (!modalPresentation.screenId) throw new Error('screen(id) preload returned no screenId')
            const modalPromise = modalReq.display({ type: 'modal', dismissible: true })
            await sleep(2000)
            modalReq.close()
            const modalOutcome = await Promise.race([
                modalPromise,
                sleep(10000).then<never>(() => { throw new Error('modal dismiss timeout after 10 s') }),
            ])
            if (!modalOutcome.presentation?.screenId) throw new Error('modal outcome missing presentation.screenId')

            const popinReq = Purchasely.presentation.screen(screenId).build()
            await popinReq.preload()
            const popinPromise = popinReq.display({
                type: 'popin',
                width: { type: 'pixel', value: 320 },
                height: { type: 'percentage', value: 0.6 },
                dismissible: true,
            })
            await sleep(2000)
            popinReq.close()
            const popinOutcome = await Promise.race([
                popinPromise,
                sleep(10000).then<never>(() => { throw new Error('popin dismiss timeout after 10 s') }),
            ])
            if (!popinOutcome.presentation?.screenId) throw new Error('popin outcome missing presentation.screenId')

            pass('T19', `screen(${screenId}) modal=${modalOutcome.closeReason} popin=${popinOutcome.closeReason}`)
        } catch (e) { fail('T19', e); suitePass = false }

        // ── T20 — config setters smoke test ───────────────────────────────────
        running('T20')
        try {
            Purchasely.allowDeeplink(true)
            Purchasely.allowDeeplink(false)
            Purchasely.allowCampaigns(true)
            Purchasely.allowCampaigns(false)
            Purchasely.setLanguage('en')
            Purchasely.setThemeMode(PLYThemeMode.SYSTEM)
            Purchasely.setLogLevel(LogLevels.DEBUG)
            Purchasely.setDebugMode(false)
            Purchasely.revokeDataProcessingConsent([PLYDataProcessingPurpose.ANALYTICS])

            // Leave global flags enabled for any manual interactions after the suite.
            Purchasely.allowDeeplink(true)
            Purchasely.allowCampaigns(true)

            pass('T20', 'allowDeeplink/allowCampaigns/setLanguage/setThemeMode/setLogLevel/setDebugMode/revokeDataProcessingConsent no-throw ✓')
        } catch (e) { fail('T20', e); suitePass = false }

        // ── T21 — synchronize() resolves OR rejects cleanly (no hang) ─────────
        // Ref: Flutter catalog T6 (dart_*_bridge_test). On a bare emulator with
        // no Play billing, synchronize() propagates the native store error
        // (BillingUnavailable) — the v6 contract. Either resolution or a clean
        // rejection passes; a hang (never settling) fails.
        running('T21')
        try {
            let detail: string
            try {
                const r = await Promise.race([
                    Purchasely.synchronize(),
                    sleep(20000).then<never>(() => {
                        throw new Error('__HANG__')
                    }),
                ])
                detail = `resolved (result=${JSON.stringify(r)})`
            } catch (e) {
                const msg = e instanceof Error ? e.message : String(e)
                if (msg === '__HANG__') {
                    throw new Error('synchronize() did not settle within 20 s (hang)')
                }
                detail = `rejected cleanly (store error: ${msg})`
            }
            pass('T21', `synchronize() ${detail}`)
        } catch (e) { fail('T21', e); suitePass = false }

        // ── T22 — default dismiss handler catches a fire-and-forget display() ──
        // Ref: default_dismiss_via_display_test.dart (+ _ios). A host-opened
        // display() with NO local onDismissed and NOT awaited must route its
        // dismissal to the global default handler. Here the dismissal is a
        // programmatic req.close() → closeReason 'programmatic'.
        running('T22')
        try {
            const defaultOutcomes22: PLYPresentationOutcome[] = []
            setDefaultPresentationDismissHandler((outcome: PLYPresentationOutcome) => {
                defaultOutcomes22.push(outcome)
            })

            // No onDismissed on the builder. T9's host-driven dismissal may
            // arrive late and close this first screen before its own close()
            // call; retry that contaminated attempt once.
            const displayAndClose22 = async () => {
                let settledBeforeClose = false
                let closeIssued = false
                const req = Purchasely.presentation.placement(PLACEMENT_AUDIENCES).build()
                const displayPromise = req.display()
                displayPromise.then(() => {
                    if (!closeIssued) settledBeforeClose = true
                })

                await sleep(3000) // let the paywall render
                closeIssued = true
                req.close() // programmatic dismissal

                const outcome = await Promise.race([
                    displayPromise,
                    sleep(15000).then<never>(() => {
                        throw new Error('dismiss timeout after 15 s')
                    }),
                ])
                return { outcome, settledBeforeClose }
            }

            let result22 = await displayAndClose22()
            if (result22.settledBeforeClose) {
                await sleep(500)
                result22 = await displayAndClose22()
            }
            if (result22.settledBeforeClose) {
                throw new Error('display was dismissed before request.close() twice')
            }
            const requestOutcome22 = result22.outcome
            if (requestOutcome22.closeReason !== 'programmatic') {
                throw new Error(
                    `request closeReason expected 'programmatic', got "${requestOutcome22.closeReason}"`
                )
            }

            const defaultOutcome22 = await waitFor(
                () => defaultOutcomes22.find((outcome) => outcome.closeReason === 'programmatic'),
                15000,
                300
            )
            if (!defaultOutcome22.presentation?.screenId) {
                throw new Error('default outcome missing presentation.screenId')
            }
            pass(
                'T22',
                `default handler caught fire-and-forget display(): ` +
                `closeReason=${defaultOutcome22.closeReason} ` +
                `presentation.screenId=${defaultOutcome22.presentation.screenId}`
            )
            removeDefaultPresentationDismissHandler()
        } catch (e) {
            fail('T22', e)
            suitePass = false
            removeDefaultPresentationDismissHandler()
        }

        await sleep(1000)

        // ── T23 — local onDismissed wins over the default handler ─────────────
        // Ref: local_dismiss_handler_test.dart. Both a global default handler AND
        // a per-request onDismissed are set: only the local one (and the awaited
        // display() future) receive the outcome; the default handler stays silent.
        running('T23')
        try {
            let defaultOutcome23: PLYPresentationOutcome | null = null
            let localOutcome23: PLYPresentationOutcome | null = null

            setDefaultPresentationDismissHandler((outcome: PLYPresentationOutcome) => {
                defaultOutcome23 = outcome
            })

            const req23 = Purchasely.presentation
                .placement(PLACEMENT_AUDIENCES)
                .onDismissed((outcome) => {
                    localOutcome23 = outcome
                })
                .build()

            const displayPromise23 = req23.display()
            await sleep(3000)
            req23.close()

            const outcome23 = await Promise.race([
                displayPromise23,
                sleep(15000).then<never>(() => {
                    throw new Error('dismiss timeout after 15 s')
                }),
            ])

            if (!localOutcome23) {
                throw new Error('local onDismissed did not fire')
            }
            if (outcome23.closeReason !== 'programmatic') {
                throw new Error(`awaited outcome closeReason expected 'programmatic', got "${outcome23.closeReason}"`)
            }
            // Give any (erroneous) default dispatch a moment before asserting silence.
            await sleep(1000)
            if (defaultOutcome23 != null) {
                throw new Error('default handler fired even though a local onDismissed was set')
            }

            pass(
                'T23',
                `local onDismissed won (closeReason=${outcome23.closeReason}); ` +
                `default handler stayed silent`
            )
            removeDefaultPresentationDismissHandler()
        } catch (e) {
            fail('T23', e)
            suitePass = false
            removeDefaultPresentationDismissHandler()
        }

        // ── T24 — user attribute listener: set + removed events ────────────────
        // Ref: user_attribute_listener_test.dart. setUserAttributeListener wires
        // onUserAttributeSet / onUserAttributeRemoved; setting an attribute emits
        // a set event (key/type/value/source), clearing emits a removed event.
        running('T24')
        const T24_KEY = 'e2e_listener_attr'
        try {
            let lastSet24: { key: string; type: any; value: any; source: any } | null = null
            let lastRemovedKey24: string | null = null

            const attrListener = Purchasely.setUserAttributeListener({
                onUserAttributeSet: (key, type, value, source) => {
                    if (key === T24_KEY) lastSet24 = { key, type, value, source }
                },
                onUserAttributeRemoved: (key) => {
                    if (key === T24_KEY) lastRemovedKey24 = key
                },
            })

            try {
                // Let the native EventChannel subscription settle before emitting.
                await sleep(1000)

                // --- set ---
                Purchasely.setUserAttributeWithString(T24_KEY, 'hello_listener')
                await waitFor(() => lastSet24, 15000, 250)
                if (lastSet24!.value !== 'hello_listener') {
                    throw new Error(`set value expected 'hello_listener', got ${JSON.stringify(lastSet24!.value)}`)
                }

                // --- removed ---
                Purchasely.clearUserAttribute(T24_KEY)
                await waitFor(() => lastRemovedKey24, 15000, 250)

                pass(
                    'T24',
                    `set(${lastSet24!.key}=${JSON.stringify(lastSet24!.value)} ` +
                    `type=${lastSet24!.type} source=${lastSet24!.source}) → ` +
                    `removed(${lastRemovedKey24})`
                )
            } finally {
                attrListener.remove()
                Purchasely.clearUserAttribute(T24_KEY)
            }
        } catch (e) { fail('T24', e); suitePass = false }

        // ── T25 — embedded <PLYPresentationView request={…}> renders ──────────
        // Ref: inline_paywall_test.dart + INLINE_PAYWALL_CLOSE.md. The RENDER
        // path is the testable one: mounting the embedded view via the `request`
        // prop resolves the preloaded presentation by requestId and emits
        // PRESENTATION_VIEWED. Native inline close TAPS are NOT delivered to the
        // embedded view under instrumentation (proven in INLINE_PAYWALL_CLOSE.md),
        // so onPresentationClosed is best-effort here and verified in the real app.
        running('T25')
        try {
            inlineClosedRef.current = null
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            let viewedEvent25: any = null
            const listener25 = Purchasely.addEventListener((event: any) => {
                if (event.name === 'PRESENTATION_VIEWED') viewedEvent25 = event
            })

            try {
                const req25 = Purchasely.presentation.placement(PLACEMENT_AUDIENCES).build()
                await req25.preload()

                // Mount the embedded paywall via the `request` prop.
                setInlineRequest(req25)

                const viewed25 = await waitFor(() => viewedEvent25, 30000, 300)

                // Programmatic teardown; observe onPresentationClosed best-effort.
                req25.close()
                await sleep(1500)
                const closeObserved = inlineClosedRef.current != null

                pass(
                    'T25',
                    `inline <PLYPresentationView request> rendered ` +
                    `placement_id=${viewed25.properties?.placement_id ?? 'n/a'} ` +
                    `onPresentationClosed observed=${closeObserved}` +
                    (closeObserved
                        ? ''
                        : ' (native inline close verified in real app — not drivable under instrumentation)')
                )
            } finally {
                setInlineRequest(null)
                listener25.remove()
            }
        } catch (e) {
            fail('T25', e)
            suitePass = false
            setInlineRequest(null)
        }

        await sleep(1000)

        // ── T26 — PLYLoadedPresentation lifecycle: display/close → outcome ─────
        // The object resolved by preload() drives its OWN lifecycle
        // (loaded.display / loaded.close / loaded.back), delegating to the
        // originating request. Programmatic close → closeReason 'programmatic'.
        running('T26')
        try {
            const req26 = Purchasely.presentation.placement(PLACEMENT_AUDIENCES).build()
            const loaded = await req26.preload()
            if (!loaded.screenId) throw new Error('preload returned no screenId')

            const displayPromise26 = loaded.display({ type: 'modal', dismissible: true })
            await sleep(2500)
            loaded.close()

            const outcome26 = await Promise.race([
                displayPromise26,
                sleep(15000).then<never>(() => {
                    throw new Error('loaded.display() dismiss timeout after 15 s')
                }),
            ])

            if (outcome26.closeReason !== 'programmatic') {
                throw new Error(`closeReason expected 'programmatic', got "${outcome26.closeReason}"`)
            }
            if (!outcome26.presentation?.screenId) {
                throw new Error('outcome missing presentation.screenId')
            }
            pass(
                'T26',
                `loaded.display({modal}) → loaded.close() → ` +
                `closeReason=${outcome26.closeReason} ` +
                `presentation.screenId=${outcome26.presentation?.screenId}`
            )
        } catch (e) { fail('T26', e); suitePass = false }

        // ── T27 — cold-start deeplink (deferred / skipped in the main suite) ───
        // Ref: deeplink_cold_start_test.dart. The builder modifier
        // `.handleDeeplink(url)` replays a launch-time deeplink after start(),
        // which the SDK auto-opens. This requires a FRESH process (the init
        // builder must chain .handleDeeplink() BEFORE start()), so it runs as a
        // dedicated cold-start phase, not mid-session.
        //   • Android: run_e2e.sh relaunches with E2E_PHASE=deeplink_coldstart →
        //     runColdStartPhase() below emits [E2E:T27:PASS|FAIL].
        //   • iOS: AppDelegate forwards only e2eMode (no phase/deeplink bridge;
        //     wiring it is outside the example/src perimeter) → explicit SKIP.
        if (Platform.OS === 'android') {
            skip('T27', 'runs in dedicated cold-start phase (E2E_PHASE=deeplink_coldstart) — see phase [E2E:T27:PASS|FAIL]')
        } else {
            skip('T27', 'iOS: cold-start deeplink phase needs an AppDelegate launch-arg → initialProp bridge (out of scope); Android-only for now')
        }

        // ── Final report ──────────────────────────────────────────────────────
        setSuiteStatus(suitePass ? 'pass' : 'fail')
        if (suitePass) {
            console.log('[E2E:SUITE:PASS] All main-suite tests passed (T1-T26; T27 in cold-start phase)')
            appendLog('=== SUITE PASS ✓ ===')
        } else {
            console.log('[E2E:SUITE:FAIL] One or more tests failed')
            appendLog('=== SUITE FAIL ✗ ===')
        }
    }

    // ── T27 — cold-start deeplink phase (own process) ──────────────────────────
    // Launched by run_e2e.sh with E2E_PHASE=deeplink_coldstart on a FRESH app
    // process. The SDK is (re)started here with `.handleDeeplink()` chained on the
    // builder BEFORE start(); the SDK then auto-opens the paywall, firing
    // DEEPLINK_OPENED → PRESENTATION_LOADED → PRESENTATION_VIEWED. We subscribe
    // to events BEFORE start() so the startup burst is not missed. The process is
    // torn down at the end, so no dismissal/driver is needed.
    async function runColdStartPhase() {
        setSuiteStatus('running')
        console.log('[E2E:SUITE:START] phase=deeplink_coldstart')
        appendLog('=== T27 cold-start deeplink phase ===')

        running('T27')
        let phasePass = true
        try {
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            const seen: Record<string, any> = {}
            const order: string[] = []
            const tracked = ['DEEPLINK_OPENED', 'PRESENTATION_LOADED', 'PRESENTATION_VIEWED']
            const listener = Purchasely.addEventListener((event: any) => {
                if (tracked.includes(event.name) && !(event.name in seen)) {
                    seen[event.name] = event
                    order.push(event.name)
                }
            })

            try {
                // The cold-start deeplink is passed to the builder — NOT replayed
                // by a manual Purchasely.handleDeeplink(...) call (that is T9).
                const b = Purchasely.builder(API_KEY)
                    .runningMode('full')
                    .logLevel('debug')
                    .allowDeeplink(true)
                    .handleDeeplink(DEEPLINK_AUDIENCES)
                const sdkOk = await (
                    Platform.OS === 'android'
                        ? b.stores(['google'])
                        : b.storekitVersion('storeKit2')
                ).start()
                if (!sdkOk) throw new Error('SDK init failed in cold-start phase')

                // Poll for the robust cross-platform invariant: DEEPLINK_OPENED and
                // PRESENTATION_VIEWED both fired (network fetch + render take time).
                await waitFor(
                    () => (seen.DEEPLINK_OPENED && seen.PRESENTATION_VIEWED ? true : null),
                    60000,
                    300
                )

                const deeplinkId = seen.DEEPLINK_OPENED?.properties?.deeplink_identifier
                if (!deeplinkId) throw new Error('DEEPLINK_OPENED missing deeplink_identifier')
                if (!String(deeplinkId).includes(PLACEMENT_AUDIENCES)) {
                    throw new Error(`deeplink_identifier "${deeplinkId}" does not reference ${PLACEMENT_AUDIENCES}`)
                }

                const iDeeplink = order.indexOf('DEEPLINK_OPENED')
                const iViewed = order.indexOf('PRESENTATION_VIEWED')
                if (!(iDeeplink >= 0 && iDeeplink < iViewed)) {
                    throw new Error(`DEEPLINK_OPENED must precede PRESENTATION_VIEWED; order=${order.join('→')}`)
                }

                const sdkVersion = seen.PRESENTATION_VIEWED?.properties?.sdk_version
                if (!sdkVersion) throw new Error('PRESENTATION_VIEWED missing sdk_version')

                pass(
                    'T27',
                    `cold-start deeplink: order=${order.join('→')} ` +
                    `deeplink_identifier=${deeplinkId} sdk_version=${sdkVersion}`
                )
            } finally {
                listener.remove()
            }
        } catch (e) { fail('T27', e); phasePass = false }

        setSuiteStatus(phasePass ? 'pass' : 'fail')
        if (phasePass) {
            console.log('[E2E:SUITE:PASS] cold-start deeplink phase (T27)')
            appendLog('=== T27 PHASE PASS ✓ ===')
        } else {
            console.log('[E2E:SUITE:FAIL] cold-start deeplink phase (T27)')
            appendLog('=== T27 PHASE FAIL ✗ ===')
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
        <View style={styles.root}>
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
                        t.status === 'skip' && styles.testSkip,
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
                        {t.status === 'skip' && '⊘'}
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

        {/* T25: embedded paywall overlay — mounted only while the inline view is
            under test. The native view resolves the preloaded request by
            requestId (no second preload). */}
        {inlineRequest && (
            <View style={styles.inlineOverlay}>
                <PLYPresentationView
                    request={inlineRequest}
                    flex={1}
                    onPresentationClosed={(result) => {
                        inlineClosedRef.current = result
                        console.log(
                            '[E2E:T25] inline onPresentationClosed',
                            JSON.stringify(result)
                        )
                    }}
                />
            </View>
        )}
        </View>
    )
}

// ── Styles ────────────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
    root: { flex: 1, backgroundColor: '#121212' },
    container: { flex: 1, backgroundColor: '#121212' },
    inlineOverlay: {
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: '#000',
    },
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
    testSkip: { backgroundColor: '#37474f' },
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
