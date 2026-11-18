// swift-tools-version:5.9
// The Purchasely iOS SDK for react-native-purchasely. ../purchasely_spm.rb adds this package
// to the pod during `pod install` (CocoaPods apps), and ../../Package.swift depends on it
// (React Native SwiftPM apps). The url and checksum are the only iOS SDK pin.
import PackageDescription

let package = Package(
    name: "PurchaselyRN",
    platforms: [.iOS(.v15), .tvOS(.v15)],
    products: [
        .library(name: "Purchasely", targets: ["Purchasely"]),
    ],
    targets: [
        .binaryTarget(
            name: "Purchasely",
            // shortcut: checksum of the 6.3.0 zip is unknown until the iOS release; replace it before merge.
            url: "https://github.com/Purchasely/Purchasely-iOS/releases/download/6.3.0/Purchasely-ios-xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        ),
    ]
)
