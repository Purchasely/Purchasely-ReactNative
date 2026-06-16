#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Workaround for an upstream packaging bug in @react-native-community/cli@20.x:
 * the published tarball ships `build/bin.js` with mode 0644 (not executable).
 * Under Yarn 3's node-modules linker the missing executable bit is preserved,
 * so when Gradle's autolinking step invokes the `rnc-cli` binary via `npx`/`sh`
 * (see example/android/settings.gradle -> autolinkLibrariesFromCommand()), it
 * fails with "Permission denied" (exit 126) and the Android build aborts.
 *
 * npm normally fixes this from the package `bin` field; Yarn does not, so we
 * restore the executable bit on every install. Safe no-op on Windows.
 */
const fs = require('fs')
const path = require('path')

if (process.platform === 'win32') {
  process.exit(0)
}

const roots = [
  path.join(__dirname, '..', 'node_modules'),
  path.join(__dirname, '..', 'example', 'node_modules'),
]

let fixed = 0

for (const root of roots) {
  const binJs = path.join(
    root,
    '@react-native-community',
    'cli',
    'build',
    'bin.js'
  )
  try {
    if (fs.existsSync(binJs)) {
      fs.chmodSync(binJs, 0o755)
      fixed += 1
    }
  } catch (err) {
    console.warn(
      `[fix-rnc-cli-permissions] could not chmod ${binJs}: ${err.message}`
    )
  }
}

if (fixed > 0) {
  console.log(
    `[fix-rnc-cli-permissions] restored +x on ${fixed} @react-native-community/cli bin(s)`
  )
}
