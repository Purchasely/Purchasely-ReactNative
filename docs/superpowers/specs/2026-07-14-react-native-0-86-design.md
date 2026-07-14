# React Native 0.86 Validation Design

**Scope:** React Native SDK only; branch targets `feat/sdk-v6-migration`.

The existing React Native 0.86 test project will become the compatibility sample. It will consume local v6 packages, align its tooling with RN 0.86, enable the New Architecture, and build on Android and iOS in CI. The sample will explicitly expose fullscreen and embedded `PLYPresentationView` validation paths.

Because the SDK uses the classic bridge and view manager, no TurboModule migration is implied. Modal, keyboard, safe-area, edge-to-edge, and rotation validation will be automated when deterministic and otherwise captured in a concise manual test checklist. No public API change is planned.
