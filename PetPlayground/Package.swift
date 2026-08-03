// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "PetPlayground",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.executable(name: "PetPlayground", targets: ["PetPlayground"])],
    targets: [
        .executableTarget(name: "PetPlayground", resources: [.process("Resources")]),
        .testTarget(name: "PetPlaygroundTests", dependencies: ["PetPlayground"])
    ]
)
