//
//  PurchaselyRN+Interceptors.swift
//  register/unregister/complete the client action interceptor, plus the
//  30-second timeout that guarantees the SDK's completion always fires.
//
//  Ported from PurchaselyRN.m:1893-2086 (Task 13 of the Swift bridge
//  migration plan). Transliteration only — see the plan's Global
//  Constraints before touching anything here.
//

import Foundation
import Purchasely

extension PurchaselyRN {

    // MARK: - registerActionInterceptor (PurchaselyRN.m:1893-1941)

    @objc(registerActionInterceptor:)
    func registerActionInterceptor(_ kind: String?) {
        guard let kind, let nativeAction = Self.presentationAction(from: kind) else {
            // Fix 4: PurchaselyRN.m:1898 is `RCTLogWarn(@"[Purchasely] unknown
            // interceptor kind: %@", kind)` — restore the exact message text,
            // prefix included.
            PLYRNLogWarn("[Purchasely] unknown interceptor kind: \(kind ?? "nil")")
            return
        }

        Self.withState {
            Self.interceptorKinds.insert(kind)
        }

        DispatchQueue.main.async {
            // Constraint 9, __weak site (PurchaselyRN.m:1916). This closure is
            // handed to the SDK and kept for as long as the interceptor is
            // registered, so it must not keep `self` alive.
            Purchasely.interceptAction(nativeAction) { [weak self] infos, params, completion in
                guard let strongSelf = self else {
                    completion(.notHandled)
                    return
                }

                let callbackId = UUID().uuidString
                Self.withState {
                    Self.interceptorCallbacks[callbackId] = { result in
                        switch result {
                        case "success": completion(.success)
                        case "failed": completion(.failed)
                        default: completion(.notHandled)
                        }
                    }
                }

                // Fallback timer mirroring the Android bridge: if JS never
                // calls completeActionInterceptor for this callbackId, fire
                // the stored callback with `notHandled` so the SDK's
                // `completion` block is always invoked and the action is
                // never frozen. Whoever removes the entry first (this timer
                // or completeActionInterceptor) wins; the loser reads nil
                // and no-ops, so the SDK completion can never fire twice.
                strongSelf.scheduleInterceptorTimeout(callbackId: callbackId)

                var info: [String: Any] = [:]
                info["contentId"] = infos.contentId
                if let presentation = infos.presentation {
                    info["presentation"] = Self.presentationToMap(presentation)
                }

                var payloadOut: [String: Any] = [:]
                if let params {
                    switch nativeAction {
                    case .navigate:
                        payloadOut["url"] = params.url?.absoluteString ?? ""
                        if let title = params.title {
                            payloadOut["title"] = title
                        }
                    case .purchase:
                        if let plan = params.plan {
                            payloadOut["plan"] = plan.asDictionary()
                        }
                        if let promoOffer = params.promoOffer {
                            // `publicId` is intentionally omitted: `PLYPromoOffer.publicId`
                            // is declared `internal` (not `@objc public`) on iOS, so it
                            // never reaches this bridge — same omission the Flutter iOS
                            // plugin makes for the same reason.
                            payloadOut["offer"] = [
                                "vendorId": promoOffer.vendorId,
                                "storeOfferId": promoOffer.storeOfferId,
                            ]
                        }
                    case .close, .closeAll:
                        // Unlike Android's PLYPresentationAction.Close(closeReason:), the
                        // iOS SDK surfaces no real close reason here — PLYInterceptorInfo
                        // and PLYPresentationActionParameters carry no such field, and the
                        // only call site is reached exclusively from in-paywall UI
                        // actions. "button" is therefore accurate for every case this SDK
                        // version can produce.
                        payloadOut["closeReason"] = "button"
                    case .openPresentation:
                        if let presentation = params.presentation {
                            payloadOut["presentationId"] = presentation
                        }
                    case .openPlacement:
                        if let placement = params.placement {
                            payloadOut["placementId"] = placement
                        }
                    case .webCheckout:
                        payloadOut["url"] = params.url?.absoluteString ?? ""
                        if let clientReferenceId = params.clientReferenceId {
                            payloadOut["clientReferenceId"] = clientReferenceId
                        }
                        if let queryParameterKey = params.queryParameterKey {
                            payloadOut["queryParameterKey"] = queryParameterKey
                        }
                        payloadOut["webCheckoutProvider"] =
                            Self.stringFromWebCheckoutProvider(params.webCheckoutProvider)
                    default:
                        break
                    }
                }

                let event: [String: Any] = [
                    "requestId": "",
                    "callbackId": callbackId,
                    "kind": kind,
                    "info": info,
                    "payload": payloadOut,
                ]
                strongSelf.emitPresentationEvent("PURCHASELY_ACTION_INTERCEPTED", body: event)
            }
        }
    }

    // MARK: - unregisterActionInterceptor (PurchaselyRN.m:2043-2059)

    @objc(unregisterActionInterceptor:)
    func unregisterActionInterceptor(_ kind: String?) {
        guard let kind, let nativeAction = Self.presentationAction(from: kind) else {
            // Fix 4: PurchaselyRN.m:2048 is `RCTLogWarn(@"[Purchasely] unknown
            // interceptor kind: %@", kind)` — restore the exact message text,
            // prefix included.
            PLYRNLogWarn("[Purchasely] unknown interceptor kind: \(kind ?? "nil")")
            return
        }

        Self.withState {
            Self.interceptorKinds.remove(kind)
        }

        DispatchQueue.main.async {
            Purchasely.removeActionInterceptor(nativeAction)
        }
    }

    // MARK: - completeActionInterceptor (PurchaselyRN.m:2061-2073)

    @objc(completeActionInterceptor:result:)
    func completeActionInterceptor(_ callbackId: String?, result: String?) {
        guard let callbackId else { return }
        let callback = Self.withState { Self.interceptorCallbacks.removeValue(forKey: callbackId) }
        // Invoke outside the lock — the callback re-enters the SDK's action
        // handler. Objective-C's `cb(result)` messages `isEqualToString:` to a
        // nil `result`, which returns false for both comparisons and falls to
        // `notHandled`; the Swift callback takes a non-optional String
        // (Task 8), so the nil-to-notHandled fallback happens here instead.
        callback?(result ?? "notHandled")
    }

    // MARK: - the 30-second timeout, extracted so tests can inject a short delay

    /// Mirrors `dispatch_after` at PurchaselyRN.m:1937-1951. Named and given
    /// an injectable delay (default `interceptorTimeoutSeconds`) rather than
    /// an inline literal, so a unit test can prove a stale callback resolves
    /// to `notHandled` without waiting 30 real seconds.
    func scheduleInterceptorTimeout(
        callbackId: String,
        after delay: TimeInterval = PurchaselyRN.interceptorTimeoutSeconds
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let stale = Self.withState { Self.interceptorCallbacks.removeValue(forKey: callbackId) }
            if let stale {
                // Fix 4: PurchaselyRN.m:1947 is `RCTLogWarn(@"[Purchasely]
                // interceptor callback %@ timed out after %llds; falling back
                // to notHandled", ...)` — restore the exact message text,
                // prefix included.
                PLYRNLogWarn("[Purchasely] interceptor callback \(callbackId) timed out after \(Int(delay))s; falling back to notHandled")
                stale("notHandled")
            }
        }
    }
}
