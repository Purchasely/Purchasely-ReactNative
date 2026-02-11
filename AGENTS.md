# Repository Guidelines

## Project Structure & Module Organization
This repo is a Yarn workspaces monorepo for the Purchasely React Native SDK.
- `packages/` contains publishable modules: `purchasely` (core bridge) plus `google`, `amazon`, `huawei`, and `android-player`.
- `example/` is the reference app used for manual testing.
- `test-projects/` holds additional RN/Expo test apps.
- Core TypeScript sources live in `packages/purchasely/src/`; native bridges live in `packages/purchasely/ios/` and `packages/purchasely/android/`.
- Jest tests are in `packages/purchasely/src/__tests__/`.

## Build, Test, and Development Commands
Run these from the repo root:
- `yarn install` (or `yarn`) installs all workspace deps.
- `yarn all:prepare` builds all packages via Builder Bob.
- `yarn lint` runs ESLint; `yarn lint --fix` auto-fixes.
- `yarn typecheck` or `yarn typescript` runs TypeScript checks.
- `yarn test` runs Jest unit tests.
- Example app: `yarn example:start`, `yarn example:ios`, `yarn example:android`.

## Coding Style & Naming Conventions
- TypeScript strict mode; ESNext targets.
- Formatting: 4-space indentation, single quotes, no semicolons, trailing commas (ES5).
- Naming: `PascalCase` components, `camelCase` functions, `SCREAMING_SNAKE_CASE` constants, `PLY*` prefix for enums.
- Tools: ESLint + Prettier (via repo config).

## Testing Guidelines
- Frameworks: Jest for TS, XCTest for iOS, JUnit for Android.
- Add tests under `packages/purchasely/src/__tests__/` when adding public APIs or types.
- Prefer parity: update both iOS and Android bridge tests if you add native methods.
- Run locally: `yarn test` (TS). Native tests run from their platform directories.

## Commit & Pull Request Guidelines
- Conventional Commits required: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.
- Keep PRs small and focused; ensure lint/typecheck/tests pass.
- Use the PR template and link issues when relevant; discuss API changes with maintainers first.

## Notes for Contributors
- For native edits, open the example apps (`example/ios` in Xcode, `example/android` in Android Studio) to iterate quickly.
- Keep `types.ts`, `interfaces.ts`, and native bridges in sync for new APIs.
- See `CLAUDE.md` for more detailed repository context and additional guidance.


look at the PR https://github.com/Purchasely/Purchasely-ReactNative/pull/211, the CI failed with this error for android:
  Run yarn turbo run build:android
  Usage Error: Couldn't find a script named "turbo".
  And this one for ioS:
  Run yarn turbo run build:ios
  Usage Error: Couldn't find a script named "turbo".

  Turbo is still here, remove it and simplify the jobs build-android and build-ios