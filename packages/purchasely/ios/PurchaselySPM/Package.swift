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
            url: "https://github.com/Purchasely/Purchasely-iOS/releases/download/6.2.0/Purchasely-ios-xcframework.zip",
            checksum: "744ec43314361d93f569bf1310a8704989b93b92d8f7245cd5aa020becbb6894"
        ),
    ]
)
