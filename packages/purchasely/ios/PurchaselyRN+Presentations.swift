//
//  PurchaselyRN+Presentations.swift
//  Preload, display, close, back, BYOS, transitions, the static members the
//  embedded PurchaselyView calls, and the bodies of the three delegate
//  conformances Task 8 stubbed.
//
//  Ported from PurchaselyRN.m:76-320, :378-458, :1240-1450, :1489-1900
//  (Task 12 of the Swift bridge migration plan). Transliteration only — see
//  the plan's Global Constraints before touching anything here.
//

import Foundation
import Purchasely

/// Event names this file emits. Mirrors the `kPresentationEvent*` statics at
/// PurchaselyRN.m:29-34. `supportedEvents()` (Task 8) already lists the
/// string literals; these are just this file's local shorthand for them.
private enum PresentationEventName {
    static let loaded = "PURCHASELY_PRESENTATION_LOADED"
    static let presented = "PURCHASELY_PRESENTATION_PRESENTED"
    static let closeRequested = "PURCHASELY_PRESENTATION_CLOSE_REQUESTED"
    static let dismissed = "PURCHASELY_PRESENTATION_DISMISSED"
    static let defaultDismissed = "PURCHASELY_DEFAULT_PRESENTATION_DISMISSED"
}

extension PurchaselyBridge {

    // MARK: - PLYPresentationAction <-> wire string (PurchaselyRN.m:73-96)
    //
    // Only Task 13 (registerActionInterceptor / completeActionInterceptor)
    // consumes these, but they sit in this task's source range, so they are
    // ported here — internal, not private, exactly like presentationToMap.

    static func stringFromPresentationAction(_ action: PLYPresentationAction) -> String {
        switch action {
        case .login: return "login"
        case .purchase: return "purchase"
        case .close: return "close"
        case .closeAll: return "closeAll"
        case .restore: return "restore"
        case .navigate: return "navigate"
        case .promoCode: return "promoCode"
        case .openPresentation: return "openPresentation"
        case .openPlacement: return "openPlacement"
        case .webCheckout: return "webCheckout"
        @unknown default: return "unknown"
        }
    }

    static func presentationAction(from kind: String?) -> PLYPresentationAction? {
        switch kind {
        case "login": return .login
        case "purchase": return .purchase
        case "close": return .close
        case "closeAll": return .closeAll
        case "restore": return .restore
        case "navigate": return .navigate
        case "promoCode": return .promoCode
        case "openPresentation": return .openPresentation
        case "openPlacement": return .openPlacement
        case "webCheckout": return .webCheckout
        default: return nil
        }
    }

    // MARK: - PLYWebCheckoutProvider -> wire string (PurchaselyRN.m:104-111)

    static func stringFromWebCheckoutProvider(_ provider: PLYWebCheckoutProvider) -> String {
        switch provider {
        case .stripe: return "stripe"
        case .other: return "other"
        default: return "unknown"
        }
    }

    // MARK: - presentationToMap (PurchaselyRN.m:114-146)
    //
    // `screenId`, `language` and `plans` are non-optional in the Swift
    // protocol (.swiftinterface `protocol PLYPresentation`) — unlike the
    // ObjC nil-guards this ports from, they are set unconditionally. Every
    // other field stays per-field: `dict[k] = nil` removes the key
    // (Constraint 6), exactly matching the ObjC `if (x != nil) map[k] = x`.

    static func presentationToMap(_ presentation: any PLYPresentation) -> [String: Any] {
        var map: [String: Any] = [:]
        map["screenId"] = presentation.screenId
        // Keep `id` as a JS alias of the native `screenId` (P1.1).
        map["id"] = presentation.screenId
        map["placementId"] = presentation.placementId
        map["audienceId"] = presentation.audienceId
        map["abTestId"] = presentation.abTestId
        map["abTestVariantId"] = presentation.abTestVariantId
        map["campaignId"] = presentation.campaignId
        map["flowId"] = presentation.flowId
        map["language"] = presentation.language
        // Constraint 5: enum written into a dictionary uses .rawValue.
        map["type"] = presentation.type.rawValue
        map["height"] = presentation.height
        map["plans"] = presentation.plans.map { $0.asDictionary() }
        if let metadata = presentation.metadata {
            map["metadata"] = metadata.getRawMetadata()
        }
        return map
    }

    // MARK: - presentationErrorToMap (PurchaselyRN.m:149-159)
    //
    // `NSError.domain` / `.localizedDescription` are non-optional in Swift,
    // so the ObjC `?: @""` / `"Unknown error"` fallbacks are dead code here —
    // dropped, not reproduced.

    static func presentationErrorToMap(_ error: Error?) -> [String: Any]? {
        guard let error else { return nil }
        let nsError = error as NSError
        return [
            "code": nsError.code,
            "domain": nsError.domain,
            "message": nsError.localizedDescription,
        ]
    }

    // MARK: - PLYPurchaseResult / PLYCloseReason
    //
    // `purchaseResultOrdinal` already exists on PurchaselyBridge (Task 8's
    // skeleton) — reused here, not redefined.

    static func closeReasonToRNString(_ reason: PLYCloseReason) -> String? {
        switch reason {
        case .button: return "button"
        case .interactiveDismiss: return "backSystem"
        case .programmatic: return "programmatic"
        case .none: return nil
        @unknown default: return nil
        }
    }

    // MARK: - presentationBuilderFor (PurchaselyRN.m:203-220)

    static func presentationBuilder(
        placementId: String?, presentationId: String?, contentId: String?, isDefault: Bool
    ) -> PLYPresentationBuilder? {
        var builder: PLYPresentationBuilder?
        if let placementId {
            builder = PLYPresentationBuilder.forPlacementId(placementId)
        } else if let presentationId {
            // P1.1: `screenId` -> `forScreenId:` on iOS.
            builder = PLYPresentationBuilder.forScreenId(presentationId)
        } else if isDefault {
            builder = PLYPresentationBuilder()
        }
        if let builder, let contentId {
            builder.contentId(contentId)
        }
        return builder
    }

    // MARK: - applyPresentationDisplayOptions (PurchaselyRN.m:227-241)
    //
    // Tri-state: `as? NSNumber` is false for both an absent key and NSNull —
    // only a real bridged boolean applies. Mirrors the ObjC
    // `isKindOfClass:[NSNumber class]` guard.

    static func applyPresentationDisplayOptions(_ builder: PLYPresentationBuilder?, payload: [String: Any]?) {
        guard let builder else { return }
        if let displayCloseButton = payload?["displayCloseButton"] as? NSNumber {
            builder.displayCloseButton(displayCloseButton.boolValue)
        }
        if let displayBackButton = payload?["displayBackButton"] as? NSNumber {
            builder.displayBackButton(displayBackButton.boolValue)
        }
    }

    // MARK: - plyParseDimensionMap / plyTransitionFromMap (PurchaselyRN.m:283-353)
    //
    // Trap 4: this now builds `PLYDimension` directly and calls the SDK's
    // Swift designated initializer
    // `PLYTransition.init(type:height:width:heightPercentage:backgroundColors:dismissible:)`
    // (.swiftinterface: `final public class PLYTransition`) — this is what
    // replaces `PLYTransitionFactory` (kept alive for the ObjC .m; Task 14
    // deletes it, not this task).

    private static func dimension(type: String?, value: NSNumber?) -> PLYDimension? {
        guard let value else { return nil }
        switch type {
        case "pixel": return .value(value.intValue)
        case "percentage": return .percentage(value.floatValue)
        default: return nil
        }
    }

    private static func parseDimensionMap(_ map: Any?) -> (type: String?, value: NSNumber?) {
        guard let dict = map as? [String: Any] else { return (nil, nil) }
        return (dict["type"] as? String, dict["value"] as? NSNumber)
    }

    static func transition(from map: [String: Any]?) -> PLYTransition? {
        guard let map else {
            // No override — let the backend-defined presentation.transition apply.
            return nil
        }

        let typeString = map["type"] as? String
        var type: PLYTransitionType = .fullScreen
        switch typeString {
        case "push": type = .push
        case "modal": type = .modal
        case "drawer": type = .drawer
        case "popin": type = .popin
        case "inlinePaywall": type = .inlinePaywall
        case nil, "fullScreen": break
        default:
            PLYRNLogWarn("[Purchasely] unknown transition.type '\(typeString ?? "")', defaulting to fullScreen")
        }

        let (heightType, heightValue) = parseDimensionMap(map["height"])
        // Legacy 0…1 fallback field, kept alongside the new typed `height` so
        // the back-compat `height_percentage` wire field still gets set.
        let heightPercentage = heightType == "percentage" ? heightValue : nil
        let height = dimension(type: heightType, value: heightValue)

        let (widthType, widthValue) = parseDimensionMap(map["width"])
        let width = dimension(type: widthType, value: widthValue)

        var backgroundColors: PLYColors?
        if let colors = map["backgroundColors"] as? [String: Any] {
            let light = (colors["light"] as? String).flatMap { UIColor.ply_fromHex($0) }
            let dark = (colors["dark"] as? String).flatMap { UIColor.ply_fromHex($0) }
            if light != nil || dark != nil {
                backgroundColors = PLYColors(lightColor: light, darkColor: dark)
            }
        }

        let dismissible = (map["dismissible"] as? NSNumber)?.boolValue ?? true

        return PLYTransition(type: type, height: height, width: width,
                              heightPercentage: heightPercentage,
                              backgroundColors: backgroundColors,
                              dismissible: dismissible)
    }

    // MARK: - webRedemptionBodyWithSuccess:... (PurchaselyRN.h / PurchaselyRN.m:1402-1424)
    //
    // The exact Swift name Task 6's frozen ObjC-contract test uses for the
    // still-live PurchaselyRN. `context` and `context.subscription` are
    // separately nullable: a success can carry no context at all, and a
    // present context can carry no subscription. Same five keys on every
    // branch, NSNull for the absent ones.

    static func webRedemptionBody(
        withSuccess isSuccess: Bool,
        hasContext: Bool,
        subscription: [String: Any]?,
        replay: Bool,
        errorCode: String?,
        errorMessage: String?
    ) -> [String: Any] {
        var context: Any = NSNull()
        if hasContext {
            context = ["subscription": subscription ?? (NSNull() as Any)]
        }
        return [
            "isSuccess": isSuccess,
            "context": context,
            "replay": replay,
            "errorCode": errorCode ?? NSNull(),
            "errorMessage": errorMessage ?? NSNull(),
        ]
    }

    // MARK: - extractPresentationTargets (PurchaselyRN.m:1489-1505)
    //
    // ObjC guards each field against `[NSNull null]` explicitly; in Swift,
    // `payload?["k"] as? String` already returns nil for both an absent key
    // and an explicit NSNull, so the guard is implicit in the cast.

    struct PresentationTargets {
        var placementId: String?
        var presentationId: String?
        var contentId: String?
        var isDefault: Bool
    }

    static func extractPresentationTargets(_ payload: [String: Any]?) -> PresentationTargets {
        PresentationTargets(
            placementId: payload?["placementId"] as? String,
            // JS sends `screenId` as `presentationId` (cf. presentation.ts toNativePayload).
            presentationId: payload?["presentationId"] as? String,
            contentId: payload?["contentId"] as? String,
            isDefault: (payload?["isDefault"] as? NSNumber)?.boolValue ?? false
        )
    }

    // MARK: - static members PurchaselyView.swift calls (PurchaselyRN.h)
    //
    // Target: zero diff in PurchaselyView.swift. Signatures copied from
    // PurchaselyRN.h's nonnull/nullable annotations exactly, since Task 14's
    // rename must make these resolve unchanged at PurchaselyView.swift's
    // existing call sites.

    static func loadedPresentation(forRequestId requestId: String) -> (any PLYPresentation)? {
        withState { presentationsByRequest[requestId] }
    }

    static func takeLoadedPresentation(matchingScreenId screenId: String?, placementId: String?) -> (any PLYPresentation)? {
        guard let screenId, let placementId else { return nil }
        return withState {
            for (key, presentation) in presentationsByRequest
            where presentation.screenId == screenId && presentation.placementId == placementId {
                presentationsByRequest.removeValue(forKey: key)
                return presentation
            }
            return nil
        }
    }

    static func evictPresentationRequest(_ requestId: String?) {
        guard let requestId else { return }
        _ = withState { presentationsByRequest.removeValue(forKey: requestId) }
    }

    static func emitPresentationDismissed(forId routingId: String, outcome: PLYPresentationOutcome) {
        guard let emitter = sharedEmitter, emitter.shouldEmit else { return }

        var presentation = outcome.presentation
        if presentation == nil {
            presentation = withState { presentationsByRequest[routingId] }
        }

        var body: [String: Any] = ["requestId": routingId]
        if let presentation {
            body["presentation"] = presentationToMap(presentation)
        }
        if let ordinal = purchaseResultOrdinal(outcome.purchaseResult) {
            body["purchaseResult"] = ordinal
        }
        if let plan = outcome.plan {
            body["plan"] = plan.asDictionary()
        }
        if let error = outcome.error {
            body["error"] = presentationErrorToMap(error)
        } else if let closeReason = closeReasonToRNString(outcome.closeReason) {
            body["closeReason"] = closeReason
        }
        emitter.sendEvent(withName: PresentationEventName.dismissed, body: body)
        _ = withState { presentationsByRequest.removeValue(forKey: routingId) }
    }

    static func emitPresentationCloseRequested(forId requestId: String) {
        guard let emitter = sharedEmitter, emitter.shouldEmit else { return }
        emitter.sendEvent(withName: PresentationEventName.closeRequested, body: ["requestId": requestId])
    }

    static func emitEmbeddedPresentationViewed(forRequestId requestId: String?, placementId: String?) {
        guard let emitter = sharedEmitter, emitter.shouldEmit else { return }

        var resolvedPlacement = placementId
        if resolvedPlacement == nil, let requestId {
            resolvedPlacement = loadedPresentation(forRequestId: requestId)?.placementId
        }

        var properties: [String: Any] = [:]
        if let resolvedPlacement {
            properties["placement_id"] = resolvedPlacement
        }
        emitter.sendEvent(withName: "PURCHASELY_EVENTS",
                           body: ["name": "PRESENTATION_VIEWED", "properties": properties])
    }

    // MARK: - loadedClientPresentationForMap (PurchaselyRN.m:1855-1875)

    private static func loadedClientPresentation(for map: [String: Any]?) -> (any PLYPresentation)? {
        guard let map else { return nil }
        let screenId = (map["screenId"] as? String) ?? (map["id"] as? String)
        let placementId = map["placementId"] as? String
        return withState {
            if let screenId {
                for presentation in presentationsByRequest.values where presentation.screenId == screenId {
                    return presentation
                }
            }
            if screenId == nil, let placementId {
                for presentation in presentationsByRequest.values where presentation.placementId == placementId {
                    return presentation
                }
            }
            return nil
        }
    }

    // MARK: - preloadPresentation (PurchaselyRN.m:1517-1581)

    @objc(preloadPresentation:payload:resolve:reject:)
    func preloadPresentation(
        _ requestId: String?,
        payload: [String: Any]?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        let requestId = requestId ?? ""
        let targets = Self.extractPresentationTargets(payload)

        // Constraint 9, __weak site (PurchaselyRN.m:~1535).
        let onFetchCompletion: ((any PLYPresentation)?, Error?) -> Void = { [weak self] presentation, error in
            guard let self else { return }
            var event: [String: Any] = ["requestId": requestId]
            if let presentation {
                event["presentation"] = Self.presentationToMap(presentation)
                Self.withState { Self.presentationsByRequest[requestId] = presentation }
            }
            if let error {
                event["error"] = Self.presentationErrorToMap(error)
            }
            self.emitPresentationEvent(PresentationEventName.loaded, body: event)
        }

        DispatchQueue.main.async {
            guard let builder = Self.presentationBuilder(
                placementId: targets.placementId, presentationId: targets.presentationId,
                contentId: targets.contentId, isDefault: targets.isDefault
            ) else {
                let error = NSError(domain: "io.purchasely.presentation", code: 400,
                                     userInfo: [NSLocalizedDescriptionKey: "No placementId or screenId provided"])
                onFetchCompletion(nil, error)
                resolve(true)
                return
            }
            Self.applyPresentationDisplayOptions(builder, payload: payload)
            // Wired at preload time (mirrors Flutter's `buildRequest`, shared
            // by preload + display) so an embedded `PLYPresentationView`
            // reusing this requestId still gets its dismissal/close-request
            // emitted.
            builder.onDismissed { outcome in
                Self.emitPresentationDismissed(forId: requestId, outcome: outcome)
            }
            builder.onCloseRequested {
                Self.emitPresentationCloseRequested(forId: requestId)
            }
            let request = builder.build()
            request.preload(completion: onFetchCompletion)
            // Constraint 10: the native promise resolves once, immediately.
            // The public JS promise settles later through events.
            resolve(true)
        }
    }

    // MARK: - displayPresentation (PurchaselyRN.m:1590-1747)

    @objc(displayPresentation:payload:transition:resolve:reject:)
    func displayPresentation(
        _ requestId: String?,
        payload: [String: Any]?,
        transition transitionPayload: [String: Any]?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        let requestId = requestId ?? ""
        let targets = Self.extractPresentationTargets(payload)

        // Captured for the close-flow: lets the dismissal handler send the
        // dismissed event with the right outcome. Swift closures capture
        // `var` locals by reference, so `onDismissed` mutating these is what
        // `emitDismissed` reads — no `__block` needed.
        var capturedPresentation: (any PLYPresentation)?
        var capturedResult: PLYPurchaseResult = .cancelled
        var capturedPlan: PLYPlan?
        var hasPurchaseOutcome = false
        var capturedCloseReason: PLYCloseReason = .none

        // __weak site (PurchaselyRN.m:~1604).
        let emitDismissed: (Error?) -> Void = { [weak self] error in
            guard let self else { return }
            var body: [String: Any] = ["requestId": requestId]
            if let capturedPresentation {
                body["presentation"] = Self.presentationToMap(capturedPresentation)
            }
            if hasPurchaseOutcome {
                if let ordinal = Self.purchaseResultOrdinal(capturedResult) {
                    body["purchaseResult"] = ordinal
                }
                if let capturedPlan {
                    body["plan"] = capturedPlan.asDictionary()
                }
            }
            if let error {
                body["error"] = Self.presentationErrorToMap(error)
            } else if let closeReason = Self.closeReasonToRNString(capturedCloseReason) {
                // Exclusion rule: only surface closeReason when there is no error.
                body["closeReason"] = closeReason
            }
            self.emitPresentationEvent(PresentationEventName.dismissed, body: body)
            _ = Self.withState { Self.presentationsByRequest.removeValue(forKey: requestId) }
        }

        let onFetchCompletion: ((any PLYPresentation)?, Error?) -> Void = { [weak self] presentation, error in
            guard let self else { return }

            var loaded: [String: Any] = ["requestId": requestId]
            if let presentation {
                loaded["presentation"] = Self.presentationToMap(presentation)
            }
            if let error {
                loaded["error"] = Self.presentationErrorToMap(error)
            }
            self.emitPresentationEvent(PresentationEventName.loaded, body: loaded)

            if let error {
                // P0.4: synthesize onPresented(null, error) since the native
                // pipeline failed before the controller was shown.
                self.emitPresentationEvent(PresentationEventName.presented,
                                            body: ["requestId": requestId,
                                                   "error": Self.presentationErrorToMap(error) as Any])
                emitDismissed(error)
                return
            }

            guard let presentation else {
                let missing = NSError(domain: "io.purchasely.presentation", code: 404,
                                       userInfo: [NSLocalizedDescriptionKey: "Presentation not found"])
                self.emitPresentationEvent(PresentationEventName.presented,
                                            body: ["requestId": requestId,
                                                   "error": Self.presentationErrorToMap(missing) as Any])
                emitDismissed(missing)
                return
            }

            capturedPresentation = presentation
            Self.withState { Self.presentationsByRequest[requestId] = presentation }
            // v6: by the time this completion fires, `display(transition:
            // completion:)` has already triggered the display — there is no
            // separate native "visible" callback wired at this layer, so
            // onPresented is emitted here, mirroring the Android contract.
            self.emitPresentationEvent(PresentationEventName.presented,
                                        body: ["requestId": requestId,
                                               "presentation": Self.presentationToMap(presentation)])
        }

        // v6: the dismiss outcome is delivered through the builder's
        // `onDismissed` handler. Strong capture — the ObjC block here has no
        // `__weak`.
        let onDismissed: (PLYPresentationOutcome) -> Void = { outcome in
            capturedResult = outcome.purchaseResult
            capturedPlan = outcome.plan
            hasPurchaseOutcome = true
            capturedCloseReason = outcome.closeReason
            if let presentation = outcome.presentation {
                capturedPresentation = presentation
            }
            emitDismissed(outcome.error)
        }

        DispatchQueue.main.async {
            guard let builder = Self.presentationBuilder(
                placementId: targets.placementId, presentationId: targets.presentationId,
                contentId: targets.contentId, isDefault: targets.isDefault
            ) else {
                let error = NSError(domain: "io.purchasely.presentation", code: 400,
                                     userInfo: [NSLocalizedDescriptionKey: "No placementId or screenId provided"])
                onFetchCompletion(nil, error)
                resolve(true)
                return
            }
            Self.applyPresentationDisplayOptions(builder, payload: payload)
            builder.onDismissed(onDismissed)
            // See emitPresentationCloseRequested(forId:) — notification only,
            // does not gate the dismissal handled by onDismissed above.
            builder.onCloseRequested {
                Self.emitPresentationCloseRequested(forId: requestId)
            }
            let request = builder.build()
            // v6: display through the SDK's own path, which owns triggering
            // the presentation itself. `nil` transition honors the
            // backend-defined `presentation.transition`.
            let nativeTransition = Self.transition(from: transitionPayload)
            request.display(transition: nativeTransition, completion: onFetchCompletion)
            resolve(true)
        }
    }

    // MARK: - setDefaultPresentationDismissHandler / removeDefaultPresentationDismissHandler
    // (PurchaselyRN.m:1751-1783)
    //
    // Global handler for presentations the app did NOT instantiate itself
    // (campaigns, deeplinks, Promoted In-App Purchases). `presentation` is
    // always populated for this handler so JS can tell which campaign/
    // deeplink screen closed.

    @objc(setDefaultPresentationDismissHandler)
    func setDefaultPresentationDismissHandler() {
        // __weak site (PurchaselyRN.m:~1762).
        let handler: (PLYPresentationOutcome) -> Void = { [weak self] outcome in
            guard let self else { return }
            var body: [String: Any] = [:]
            if let presentation = outcome.presentation {
                body["presentation"] = Self.presentationToMap(presentation)
            }
            if let ordinal = Self.purchaseResultOrdinal(outcome.purchaseResult) {
                body["purchaseResult"] = ordinal
            }
            if let plan = outcome.plan {
                body["plan"] = plan.asDictionary()
            }
            if let closeReason = Self.closeReasonToRNString(outcome.closeReason) {
                body["closeReason"] = closeReason
            }
            if let error = outcome.error {
                body["error"] = Self.presentationErrorToMap(error)
            }
            self.emitPresentationEvent(PresentationEventName.defaultDismissed, body: body)
        }
        DispatchQueue.main.async {
            Purchasely.setDefaultPresentationDismissHandler(handler)
        }
    }

    @objc(removeDefaultPresentationDismissHandler)
    func removeDefaultPresentationDismissHandler() {
        DispatchQueue.main.async {
            Purchasely.setDefaultPresentationDismissHandler(nil)
        }
    }

    // MARK: - closePresentation / goBackToPreviousScreen / closeAllScreens
    // (PurchaselyRN.m:1786-1837, :1283-1286)

    // Constraint 7: the lock is taken twice, never nested. The SDK close
    // call sits OUTSIDE both `withState` blocks.
    @objc(closePresentation:)
    func closePresentation(_ requestId: String?) {
        guard let requestId else { return }
        DispatchQueue.main.async {
            let presentation = Self.withState { Self.presentationsByRequest[requestId] }
            if let presentation {
                // Programmatic close: clear onCloseRequested first so it can
                // never re-emit CLOSE_REQUESTED for this call.
                presentation.onCloseRequested = nil
                presentation.close()
            } else {
                Purchasely.closeAllScreens()
            }
            _ = Self.withState { Self.presentationsByRequest.removeValue(forKey: requestId) }
        }
    }

    @objc(goBackToPreviousScreen:)
    func goBackToPreviousScreen(_ requestId: String?) {
        guard let requestId else { return }
        DispatchQueue.main.async {
            // `back()` is a required PLYPresentation method (non-optional in
            // the Swift protocol), so the ObjC `respondsToSelector:` guard is
            // dropped — every conforming instance implements it.
            if let presentation = Self.withState({ Self.presentationsByRequest[requestId] }) {
                presentation.back()
            } else {
                PLYRNLogWarn("[Purchasely] goBackToPreviousScreen(\(requestId)): no loaded presentation to navigate back")
            }
        }
    }

    @objc(closeAllScreens)
    func closeAllScreens() {
        DispatchQueue.main.async {
            Purchasely.closeAllScreens()
        }
    }

    // MARK: - client (BYOS) presentations (PurchaselyRN.m:1840-1875)

    @objc(clientPresentationDisplayed:)
    func clientPresentationDisplayed(_ presentationMap: [String: Any]?) {
        guard let presentation = Self.loadedClientPresentation(for: presentationMap) else {
            PLYRNLogWarn("[Purchasely] clientPresentationDisplayed: no loaded presentation matches \(String(describing: presentationMap)) — preload it first with Purchasely.presentation…build().preload()")
            return
        }
        DispatchQueue.main.async {
            Purchasely.clientPresentationDisplayed(with: presentation)
        }
    }

    @objc(clientPresentationClosed:)
    func clientPresentationClosed(_ presentationMap: [String: Any]?) {
        guard let presentation = Self.loadedClientPresentation(for: presentationMap) else {
            PLYRNLogWarn("[Purchasely] clientPresentationClosed: no loaded presentation matches \(String(describing: presentationMap)) — preload it first with Purchasely.presentation…build().preload()")
            return
        }
        DispatchQueue.main.async {
            Purchasely.clientPresentationClosed(with: presentation)
        }
    }

    // MARK: - delegate bodies (replacing Task 8's stubs)

    // PLYEventDelegate. PurchaselyRN.m:1332-1341.
    func eventTriggered(_ event: PLYEvent, properties: [String: Any]?) {
        guard shouldEmit else { return }
        if let properties {
            sendEvent(withName: "PURCHASELY_EVENTS", body: ["name": NSString.fromPLYEvent(event), "properties": properties])
        } else {
            sendEvent(withName: "PURCHASELY_EVENTS", body: ["name": NSString.fromPLYEvent(event)])
        }
    }

    // PLYUserAttributeDelegate. PurchaselyRN.m:1344-1367. Only the 5-arg
    // overload is implemented — see PurchaselyRN.swift's note on why the
    // 4-arg one would silently drop processingLegalBasis.
    //
    // Re-reads `Purchasely.getUserAttribute(for:)` rather than using the
    // passed `value` — ported faithfully from PurchaselyRN.m:1358, not fixed
    // here.
    func onUserAttributeSet(key: String, type: PLYUserAttributeType, value: Any?, source: PLYUserAttributeSource, processingLegalBasis: PLYDataProcessingLegalBasis) {
        guard shouldEmit else { return }
        var body: [String: Any] = [:]
        body["key"] = key
        body["type"] = type.rawValue
        if value != nil {
            body["value"] = Self.rnValue(for: Purchasely.getUserAttribute(for: key))
        }
        body["source"] = source.rawValue
        body["processingLegalBasis"] = processingLegalBasis.rawValue
        sendEvent(withName: "USER_ATTRIBUTE_SET_LISTENER", body: body)
    }

    // PurchaselyRN.m:1369-1378.
    func onUserAttributeRemoved(key: String, source: PLYUserAttributeSource) {
        guard shouldEmit else { return }
        sendEvent(withName: "USER_ATTRIBUTE_REMOVED_LISTENER", body: ["key": key, "source": source.rawValue])
    }

    // PLYWebRedemptionDelegate. PurchaselyRN.m:1391-1403. `context` and
    // `context.subscription` are separately nullable in the emitted body.
    func webRedemptionCompleted(result: PLYWebRedemptionResult) {
        guard shouldEmit else { return }
        let subscription = result.context?.subscription
        let body = Self.webRedemptionBody(
            withSuccess: result.isSuccess,
            hasContext: result.context != nil,
            subscription: subscription.flatMap { $0.asDictionary() as? [String: Any] },
            replay: result.replay,
            errorCode: result.errorCode,
            errorMessage: result.errorMessage
        )
        sendEvent(withName: "WEB_REDEMPTION_LISTENER", body: body)
    }
}
