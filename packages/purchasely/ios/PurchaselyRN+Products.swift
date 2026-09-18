//
//  PurchaselyRN+Products.swift
//  Products, plans, subscriptions, purchase, restore, offerings, promo offers.
//
//  Ported from PurchaselyRN.m:972-1240 and :635-648 (isEligibleForIntroOffer,
//  Task 11 of the Swift bridge migration plan). Transliteration only — see
//  the plan's Global Constraints before touching anything here.
//
//  `synchronize` is Task 9's, not this task's — it is not redeclared here.
//

import Foundation
import Purchasely

extension PurchaselyRN {

    // MARK: - promo offer lookup (purchaseWithPlanVendorId helper)

    /// Ported from the inline loop in `purchaseWithPlanVendorId:offerId:...`
    /// (PurchaselyRN.m:1001-1009): find the `storeOfferId` of the plan's
    /// promo offer whose `vendorId` matches `offerId`. Returns nil if there
    /// is no match, exactly as the loop falls through with `storeOfferId`
    /// left nil.
    static func storeOfferId(forOfferId offerId: String, in plan: PLYPlan) -> String? {
        for promoOffer in plan.promoOffers where promoOffer.vendorId == offerId {
            return promoOffer.storeOfferId
        }
        return nil
    }

    // MARK: - purchase

    @objc(purchaseWithPlanVendorId:offerId:contentId:resolve:reject:)
    func purchaseWithPlanVendorId(
        _ planVendorId: String?,
        offerId: String?,
        contentId: String?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        DispatchQueue.main.async {
            Purchasely.plan(with: planVendorId ?? "", success: { plan in
                // PurchaselyRN.m:1001-1035: the promotional-offer purchase
                // path is only available from iOS 12.2 / tvOS 15.0 onward;
                // below that, always fall back to the plain purchase.
                if #available(iOS 12.2, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                    let storeOfferId = offerId.flatMap { Self.storeOfferId(forOfferId: $0, in: plan) }
                    if let storeOfferId {
                        Purchasely.purchaseWithPromotionalOffer(
                            plan: plan, contentId: contentId, storeOfferId: storeOfferId,
                            success: {
                                resolve(plan.asDictionary())
                            }, failure: { error in
                                Self.reject(reject, with: error)
                            }
                        )
                    } else {
                        Purchasely.purchase(plan: plan, contentId: contentId, success: {
                            resolve(plan.asDictionary())
                        }, failure: { error in
                            Self.reject(reject, with: error)
                        })
                    }
                } else {
                    Purchasely.purchase(plan: plan, contentId: contentId, success: {
                        resolve(plan.asDictionary())
                    }, failure: { error in
                        Self.reject(reject, with: error)
                    })
                }
            }, failure: { error in
                Self.reject(reject, with: error)
            })
        }
    }

    // MARK: - restore

    // Constraint 3: the JS name is "restoreAllProducts" but the original
    // RCT_REMAP_METHOD gave it the bare selector fragment `resolve:reject:`
    // (PurchaselyRN.m:1046-1056). The shim's selector must match this exact
    // @objc annotation.
    @objc(restoreAllProducts:reject:)
    func restoreAllProducts(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            Purchasely.restoreAllProducts(success: {
                resolve(true)
            }, failure: { error in
                Self.reject(reject, with: error)
            })
        }
    }

    // Constraint 3: same shape — original selector fragment was
    // `silentRestoreWithResolve:reject:` (PurchaselyRN.m:1060-1070). Note the
    // body is faithful to the Objective-C: despite the JS name, it calls
    // `Purchasely.synchronize`, not `restoreAllProducts`.
    @objc(silentRestoreAllProducts:reject:)
    func silentRestoreAllProducts(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            Purchasely.synchronize(success: {
                resolve(true)
            }, failure: { error in
                Self.reject(reject, with: error)
            })
        }
    }

    // MARK: - products / plans

    @objc(allProducts:reject:)
    func allProducts(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            Purchasely.allProducts(success: { products in
                resolve(products.map { $0.asDictionary() })
            }, failure: { error in
                Self.reject(reject, with: error)
            })
        }
    }

    @objc(productWithIdentifier:resolve:reject:)
    func productWithIdentifier(
        _ productVendorId: String?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        DispatchQueue.main.async {
            Purchasely.product(with: productVendorId ?? "", success: { product in
                resolve(product.asDictionary())
            }, failure: { error in
                Self.reject(reject, with: error)
            })
        }
    }

    @objc(planWithIdentifier:resolve:reject:)
    func planWithIdentifier(
        _ planVendorId: String?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        DispatchQueue.main.async {
            Purchasely.plan(with: planVendorId ?? "", success: { plan in
                resolve(plan.asDictionary())
            }, failure: { error in
                Self.reject(reject, with: error)
            })
        }
    }

    // MARK: - subscriptions

    // Constraint 4: `invalidate`/`invalidateCache` are a C primitive (BOOL)
    // today, so they stay a primitive Bool, unlike the object-typed params
    // elsewhere in this file.
    // Constraint 6: a nil `subscriptions` array coalesces to `[]`, it does
    // not vanish (PurchaselyRN.m:1144-1152). `PLYSubscription.asDictionary()`
    // is the Objective-C category from `PLYSubscription+Hybrid.m`, kept per
    // amendment A2 — not ported here.
    @objc(userSubscriptions:resolve:reject:)
    func userSubscriptions(
        _ invalidate: Bool,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        DispatchQueue.main.async {
            Purchasely.userSubscriptions(invalidate, success: { subscriptions in
                resolve((subscriptions ?? []).map { $0.asDictionary() })
            }, failure: { error in
                Self.reject(reject, with: error)
            })
        }
    }

    @objc(userSubscriptionsHistory:resolve:reject:)
    func userSubscriptionsHistory(
        _ invalidateCache: Bool,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        DispatchQueue.main.async {
            Purchasely.userSubscriptionsHistory(invalidateCache, success: { subscriptions in
                resolve((subscriptions ?? []).map { $0.asDictionary() })
            }, failure: { error in
                Self.reject(reject, with: error)
            })
        }
    }

    // MARK: - dynamic offerings

    @objc(setDynamicOffering:planVendorId:offerId:billingPlanType:resolve:reject:)
    func setDynamicOffering(
        _ reference: String?,
        planVendorId: String?,
        offerId: String?,
        billingPlanType: String?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        DispatchQueue.main.async {
            Purchasely.setDynamicOffering(
                reference: reference ?? "",
                planVendorId: planVendorId ?? "",
                offerVendorId: offerId,
                billingPlanType: PLYPlan.billingPlanType(fromRNString: billingPlanType),
                completion: { result in
                    resolve(result)
                }
            )
        }
    }

    /// Ported from the `getDynamicOfferings` map-building loop
    /// (PurchaselyRN.m:1189-1209). Constraint 6: `offerVendorId` is omitted
    /// from the dictionary when `offering.offerId` is nil, it is not emitted
    /// as `NSNull`.
    static func offeringDictionary(_ offering: PLYOffering) -> [String: Any] {
        var map: [String: Any] = [:]
        map["reference"] = offering.reference
        map["planVendorId"] = offering.planId
        if let offerId = offering.offerId {
            map["offerVendorId"] = offerId
        }
        map["billingPlanType"] = PLYPlan.rnString(fromBillingPlanType: offering.billingPlanType)
        return map
    }

    @objc(getDynamicOfferings:reject:)
    func getDynamicOfferings(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            Purchasely.getDynamicOfferings(completion: { offerings in
                resolve(offerings.map { Self.offeringDictionary($0) })
            })
        }
    }

    @objc(removeDynamicOffering:)
    func removeDynamicOffering(_ reference: String?) {
        DispatchQueue.main.async {
            Purchasely.removeDynamicOffering(reference: reference ?? "")
        }
    }

    @objc(clearDynamicOfferings)
    func clearDynamicOfferings() {
        DispatchQueue.main.async {
            Purchasely.clearDynamicOfferings()
        }
    }

    // MARK: - promotional offer signature

    @objc(signPromotionalOffer:storeOfferId:resolve:reject:)
    func signPromotionalOffer(
        _ storeProductId: String?,
        storeOfferId: String?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        DispatchQueue.main.async {
            if #available(iOS 12.2, *) {
                Purchasely.signPromotionalOffer(
                    storeProductId: storeProductId ?? "",
                    storeOfferId: storeOfferId ?? "",
                    success: { signature in
                        resolve(signature.asDictionary())
                    }, failure: { error in
                        Self.reject(reject, with: error)
                    }
                )
            } else {
                Self.reject(reject, with: nil)
            }
        }
    }

    // MARK: - intro offer eligibility

    @objc(isEligibleForIntroOffer:resolve:reject:)
    func isEligibleForIntroOffer(
        _ planVendorId: String?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        DispatchQueue.main.async {
            Purchasely.plan(with: planVendorId ?? "", success: { plan in
                plan.isUserEligibleForIntroductoryOffer(completion: { isEligible in
                    resolve(isEligible)
                })
            }, failure: { error in
                Self.reject(reject, with: error)
            })
        }
    }
}
