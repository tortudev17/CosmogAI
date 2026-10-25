// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CosmogAI",
    products: [
        .library(name: "CosmogAI", targets: ["CosmogAI"]),
        .executable(name: "cosmogai", targets: ["CosmogAIRunner"]),
    ],
    targets: [
        .target(name: "CosmogAI"),
        .executableTarget(name: "CosmogAIRunner", dependencies: ["CosmogAI"]),
    ]
)
