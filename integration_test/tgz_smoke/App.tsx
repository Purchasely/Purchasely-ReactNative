// Launch smoke for a client app that installed the packed react-native-purchasely tarball.
// CI copies this file over App.tsx of test-projects/rn-purchasely-test (never committed there).
// The markers go through console.error so that they reach the system log of a Release build.
import React, { useEffect } from 'react'
import { Text } from 'react-native'
import Purchasely from 'react-native-purchasely'

const API_KEY = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87'

async function run(): Promise<void> {
    console.error('[TGZ:START]')
    // A slow or failing backend must not fail this check: ci.yml gates publish.yml, and the
    // check is about the packed bridge and its SDK framework. The wait is bounded below the
    // LAUNCH_WAIT of launch_check.sh (15 s), and T13 still runs after an error or a timeout.
    try {
        await Promise.race([
            Purchasely.builder(API_KEY).runningMode('full').start(),
            new Promise((_, reject) =>
                setTimeout(
                    () => reject(new Error('start() took more than 8 s')),
                    8000
                )
            ),
        ])
    } catch (e) {
        console.error(`[TGZ:START:ERROR] ${e}`)
    }
    try {
        // T13 logic: write then read a user attribute through the bridge.
        Purchasely.setUserAttributeWithString('tgz_str', 'hello_tgz')
        await new Promise<void>((resolve) => setTimeout(resolve, 300))
        const value = await Purchasely.userAttribute('tgz_str')
        if (value !== 'hello_tgz')
            throw new Error(`got ${JSON.stringify(value)}`)
        console.error('[TGZ:T13:PASS]')
    } catch (e) {
        console.error(`[TGZ:T13:FAIL] ${e}`)
    }
}

export default function App(): React.JSX.Element {
    useEffect(() => {
        run().catch((e) => console.error(`[TGZ:T13:FAIL] ${e}`))
    }, [])
    return <Text>tgz smoke</Text>
}
