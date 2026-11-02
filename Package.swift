// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ZHHTextKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "ZHHTextKit", targets: ["ZHHTextKit"])
    ],
    targets: [
        .target(
            name: "ZHHTextKit",
            path: "ZHHTextKit",
            exclude: ["Assets"],
            sources: ["Classes"],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
