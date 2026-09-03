/**
 * Client-configuration reproduction harness — "La Croix Preprod".
 *
 * Reproduces the client's exact inline-banner shape: TWO
 * `<PLYPresentationView placementId=… />` mounted at once, one inside a
 * react-native-screens screen (home-list banner) and one inside a
 * react-native-pager-view page (in-article banner). Routed the same way
 * E2ETestRunner is: the host launches with the existing E2E_MODE / E2E_PHASE
 * plumbing (AppDelegate/MainActivity, unchanged) and sets phase to
 * `BAYARD_PHASE` below — E2ETestRunner.tsx renders this component instead of
 * running the normal suite. The main T1-T30 suite is untouched and still runs
 * for every other phase value.
 *
 * All log lines carry the `[BAYARD]` prefix so a host script can grep them.
 */

import React, { useEffect, useRef, useState } from 'react'
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native'
import { ScreenStack, ScreenStackItem } from 'react-native-screens'
import PagerView from 'react-native-pager-view'
import Purchasely, { PLYPresentationView } from 'react-native-purchasely'

export const LOG_PREFIX = '[BAYARD]'
export const API_KEY = '48b5e4fa-57dc-4234-a107-e4dc4d5a8b0b'
export const PLACEMENT_HOME = 'autopro_subscriber_homepage_1'
export const PLACEMENT_ARTICLE = 'autopro_subscriber_article_body'

function log(line: string) {
    console.log(`${LOG_PREFIX} ${line}`)
}

function Banner({
    placementId,
    slot,
    testID,
}: {
    placementId: string
    slot: string
    testID: string
}) {
    return (
        <View
            testID={testID}
            style={styles.bannerSlot}
            onLayout={(e) => {
                const { x, y, width, height } = e.nativeEvent.layout
                log(
                    `layout slot=${slot} placementId=${placementId} ` +
                        `frame={x:${x},y:${y},w:${width},h:${height}}`
                )
            }}
        >
            <PLYPresentationView
                placementId={placementId}
                flex={1}
                onPresentationClosed={(outcome) =>
                    log(
                        `onPresentationClosed slot=${slot} placementId=${placementId} ` +
                            `closeReason=${outcome.closeReason} error=${outcome.error?.message ?? 'none'}`
                    )
                }
            />
        </View>
    )
}

export default function BayardReproScreen() {
    const [sdkReady, setSdkReady] = useState(false)
    // (a) navigate away / back: pushing a second ScreenStackItem on top of the
    // home screen covers it exactly like a react-navigation push would.
    const [homeNavAway, setHomeNavAway] = useState(false)
    // (b) unmount entirely.
    const [homeMounted, setHomeMounted] = useState(true)
    const [articleMounted, setArticleMounted] = useState(true)
    // (c) rapid switch slot: same mounted <PLYPresentationView>, placementId
    // flipped between the two placements — exercises the preload generation
    // guard (mounting placement B before placement A's preload settled must
    // not let A's stale preload land in B's slot).
    const [swapPlacement, setSwapPlacement] = useState(PLACEMENT_HOME)
    const navAwayTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

    useEffect(() => {
        let mounted = true
        async function init() {
            log('SDK init start (La Croix Preprod)')
            try {
                const ok = await Purchasely.builder(API_KEY)
                    .runningMode('full')
                    .logLevel('debug')
                    .start()
                if (!mounted) return
                log(`SDK init ok=${ok}`)
                setSdkReady(ok)
            } catch (e) {
                log(`SDK init FAILED ${String(e)}`)
            }
        }
        init()

        Purchasely.addEventListener((event) => {
            log(`event name=${event.name} placement_id=${event.properties?.placement_id ?? 'n/a'}`)
        })

        return () => {
            mounted = false
            if (navAwayTimer.current) clearTimeout(navAwayTimer.current)
        }
    }, [])

    function navigateAwayThenBack() {
        log('nav-away: pushing covering screen over home banner')
        setHomeNavAway(true)
        navAwayTimer.current = setTimeout(() => {
            log('nav-back: popping back to home banner screen')
            setHomeNavAway(false)
        }, 1200)
    }

    function toggleHomeMounted() {
        setHomeMounted((m) => {
            log(`home banner ${m ? 'UNMOUNT' : 'REMOUNT'}`)
            return !m
        })
    }

    function toggleArticleMounted() {
        setArticleMounted((m) => {
            log(`article banner ${m ? 'UNMOUNT' : 'REMOUNT'}`)
            return !m
        })
    }

    function rapidSwitch() {
        setSwapPlacement((p) => {
            const next = p === PLACEMENT_HOME ? PLACEMENT_ARTICLE : PLACEMENT_HOME
            log(`rapid-switch slot: ${p} -> ${next}`)
            return next
        })
    }

    return (
        <View style={styles.root} testID="bayard-repro-root">
            <ScrollView contentContainerStyle={styles.controls}>
                <Text style={styles.title}>BAYARD repro — La Croix Preprod</Text>
                <Text style={styles.sub}>sdkReady={String(sdkReady)}</Text>

                <Pressable
                    testID="bayard-nav-away-back"
                    style={styles.button}
                    onPress={navigateAwayThenBack}
                >
                    <Text style={styles.buttonText}>Navigate away & back (home banner)</Text>
                </Pressable>

                <Pressable
                    testID="bayard-unmount-home"
                    style={styles.button}
                    onPress={toggleHomeMounted}
                >
                    <Text style={styles.buttonText}>
                        {homeMounted ? 'Unmount' : 'Remount'} home banner
                    </Text>
                </Pressable>

                <Pressable
                    testID="bayard-unmount-article"
                    style={styles.button}
                    onPress={toggleArticleMounted}
                >
                    <Text style={styles.buttonText}>
                        {articleMounted ? 'Unmount' : 'Remount'} article banner
                    </Text>
                </Pressable>

                <Pressable
                    testID="bayard-rapid-switch"
                    style={styles.button}
                    onPress={rapidSwitch}
                >
                    <Text style={styles.buttonText}>
                        Rapid switch slot: currently {swapPlacement} (tap repeatedly)
                    </Text>
                </Pressable>
            </ScrollView>

            {/* (d) both real banners mounted at once. Home banner lives inside a
                react-native-screens ScreenStackItem — the exact ancestor that
                crashed on iOS (RNSScreen owning the UIViewController). */}
            <View style={styles.stage} testID="bayard-stage">
                {homeMounted && (
                    <View style={styles.homeHost} testID="bayard-home-host">
                        <ScreenStack style={styles.fill}>
                            <ScreenStackItem screenId="bayard-home" style={styles.fill}>
                                <Banner
                                    placementId={PLACEMENT_HOME}
                                    slot="home"
                                    testID="bayard-home-banner"
                                />
                            </ScreenStackItem>
                            {homeNavAway && (
                                <ScreenStackItem screenId="bayard-home-away" style={styles.fill}>
                                    <View style={styles.awayScreen}>
                                        <Text style={styles.awayText}>away…</Text>
                                    </View>
                                </ScreenStackItem>
                            )}
                        </ScreenStack>
                    </View>
                )}

                {articleMounted && (
                    <View style={styles.pagerHost} testID="bayard-pager-host">
                        <PagerView style={styles.fill} initialPage={0}>
                            <View key="article-body" style={styles.fill}>
                                <Text style={styles.pagerLabel}>article body text…</Text>
                                <Banner
                                    placementId={PLACEMENT_ARTICLE}
                                    slot="article"
                                    testID="bayard-article-banner"
                                />
                            </View>
                            <View key="next-article" style={styles.fill}>
                                <Text style={styles.pagerLabel}>next article (swipe)</Text>
                            </View>
                        </PagerView>
                    </View>
                )}

                <View style={styles.swapHost} testID="bayard-swap-host">
                    <Banner
                        placementId={swapPlacement}
                        slot="swap"
                        testID="bayard-swap-banner"
                    />
                </View>
            </View>
        </View>
    )
}

const styles = StyleSheet.create({
    root: { flex: 1, backgroundColor: '#121212' },
    fill: { flex: 1 },
    controls: { padding: 12, paddingTop: 50 },
    title: { color: '#fff', fontSize: 16, fontWeight: '700' },
    sub: { color: '#aaa', fontSize: 12, marginBottom: 8 },
    button: {
        backgroundColor: '#2c2c2e',
        borderRadius: 8,
        padding: 10,
        marginTop: 8,
    },
    buttonText: { color: '#fff', fontSize: 13 },
    stage: { flex: 1, flexDirection: 'column' },
    homeHost: { height: 140 },
    pagerHost: { height: 140 },
    swapHost: { height: 100 },
    pagerLabel: { color: '#fff', fontSize: 12, padding: 4 },
    bannerSlot: { flex: 1, backgroundColor: '#7f0000' },
    awayScreen: { flex: 1, backgroundColor: '#000', alignItems: 'center', justifyContent: 'center' },
    awayText: { color: '#fff' },
})
