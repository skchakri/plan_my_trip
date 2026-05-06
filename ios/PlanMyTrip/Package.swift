// swift-tools-version: 5.9
// This Package.swift is provided as a reference for the SPM dependency you'll add
// to the Xcode project (File → Add Package Dependencies).
// You do NOT build the iOS app from this file directly.

import PackageDescription

let package = Package(
    name: "PlanMyTripDeps",
    platforms: [.iOS(.v16)],
    products: [],
    dependencies: [
        .package(url: "https://github.com/hotwired/hotwire-native-ios", from: "1.0.0")
    ],
    targets: []
)
