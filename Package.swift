// swift-tools-version: 5.9
import PackageDescription
import Foundation

let packageRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .path

let package = Package(
    name: "libcaff4-spm",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "Libcaff4",
            targets: ["Libcaff4"]
        ),
    ],
    targets: [
        .target(
            name: "Ccaff4",
            path: "Sources/Ccaff4",
            sources: ["placeholder.c"],
            publicHeadersPath: "include",
            cxxSettings: [
                .define("SPDLOG_HEADER_ONLY"),
                .headerSearchPath("include"),
                .headerSearchPath("include/spdlog"),
            ],
            linkerSettings: [
                .linkedLibrary("aff4"),
                .linkedLibrary("raptor2"),
                .linkedLibrary("lz4"),
                .linkedLibrary("snappy"),
                .linkedLibrary("uriparser"),
                .linkedLibrary("z"),
                .linkedLibrary("crypto"),
                .linkedLibrary("ssl"),
                .linkedLibrary("c++"),
                .linkedLibrary("pthread"),
                .linkedLibrary("xml2"),
                .linkedLibrary("xslt"),
                .linkedLibrary("iconv"),
                .linkedLibrary("curl"),
                // Xcode resolves SPM package paths differently from `swift build`.
                // Using #filePath (absolute path to this Package.swift at build time)
                // ensures the -L flag resolves correctly in both contexts.
                // Do NOT replace with a relative path like "-LSources/Ccaff4" — it breaks Xcode builds.
                .unsafeFlags(["-L\(packageRoot)/Sources/Ccaff4"])
            ]
        ),
        .target(
            name: "Libcaff4",
            dependencies: ["Ccaff4"],
            path: "Sources/Libcaff4"
        ),
        .testTarget(
            name: "Libcaff4Tests",
            dependencies: ["Libcaff4"],
            path: "Tests/Libcaff4Tests",
            resources: [
                .copy("TestImages")
            ]
        )
    ]
)
