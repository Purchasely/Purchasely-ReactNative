/**
 * E2E test runner — T1–T20
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
    LogLevels,
    PLYDataProcessingPurpose,
    PLYPresentationType,
    PLYThemeMode,
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
    { id: 'T14', name: 'user attributes: double + date + arrays', status: 'pending' },
    { id: 'T15', name: 'user attributes: bulk map + clear + clear built-ins', status: 'pending' },
    { id: 'T16', name: 'user attributes: increment + decrement', status: 'pending' },
    { id: 'T17', name: 'catalog lookup: product + plan + intro eligibility', status: 'pending' },
    { id: 'T18', name: 'dynamic offerings: set/get/remove/clear', status: 'pending' },
    { id: 'T19', name: 'presentation.screen(id) + modal/popin transitions', status: 'pending' },
    { id: 'T20', name: 'config setters smoke test', status: 'pending' },
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

        // ── Final report ──────────────────────────────────────────────────────
        setSuiteStatus(suitePass ? 'pass' : 'fail')
        if (suitePass) {
            console.log('[E2E:SUITE:PASS] All 20 tests passed')
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
