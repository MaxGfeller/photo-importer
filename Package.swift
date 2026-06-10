// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CardImporter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CardImporter", targets: ["CardImporter"])
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite",
            pkgConfig: "sqlite3"
        ),
        .executableTarget(
            name: "CardImporter",
            dependencies: ["CSQLite"],
            path: "Sources/CardImporter",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
