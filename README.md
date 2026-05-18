# libcaff4-spm

A Swift Package (SPM) that wraps [Velocidex/c-aff4](https://github.com/Velocidex/c-aff4) as a universal static library for reading AFF4 forensic disk images on macOS.

---

## What This Is

`libcaff4-spm` provides a clean Swift API for opening and reading AFF4 (`.aff4`) forensic images on macOS. It wraps the `c-aff4` C++ library behind a pure C interface (`libaff4-c.h`) and exposes it to Swift via a type-safe wrapper.

The package ships prebuilt universal fat binaries (arm64 + x86_64) for `libaff4` and all its dependencies — no separate library installation required.

---

## Requirements

- macOS 13.0+
- Xcode 15+

---

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/saadtahir-dev/libcaff4-spm.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "Libcaff4", package: "libcaff4-spm")
        ]
    )
]
```

Or add via Xcode: **File → Add Package Dependencies** → paste the repo URL.

---

## Usage

```swift
import Libcaff4

// Get library version
let version = AFF4Client.version()

// Open an AFF4 image
do {
    let image = try AFF4Image(path: "/path/to/image.aff4")
    print("Image size: \(image.size) bytes")

    // Read bytes at offset
    let data = try image.read(offset: 0, length: 512)
    print("Read \(data.count) bytes")

    // Explicit close for deterministic cleanup (deinit also calls close)
    image.close()
} catch let error as AFF4Error {
    print("Failed: \(error.localizedDescription)")
}
```

---

## API

### `AFF4Image`

`AFF4Image` is `@unchecked Sendable` — operations are serialized internally via a lock, so it is safe to use from concurrent contexts.

`deinit` calls `close()` automatically, so explicit `close()` is optional but recommended for deterministic resource cleanup.

| Method / Property | Description |
|---|---|
| `init(path: String, maxChunkSize: Int = 1_048_576) throws` | Opens an AFF4 image. `maxChunkSize` controls the internal read buffer size in bytes. Throws `AFF4Error.openFailed` if the image cannot be opened. |
| `let path: String` | The path used to open this image. |
| `let size: UInt64` | Total size of the image in bytes. Fixed after open. |
| `func read(offset: UInt64, length: Int) throws -> Data` | Reads bytes at the given offset. Reads in chunks of `maxChunkSize` internally. Throws `AFF4Error.invalidHandle` if closed, `AFF4Error.readFailed` on read errors. |
| `func close()` | Closes the image handle. Safe to call multiple times. |

---

### `AFF4Client`

| Method | Description |
|---|---|
| `static func version() -> String` | Returns the libaff4 version string. |
| `static func setVerbosity(_ level: AFF4_LOG_LEVEL)` | Sets the global logging verbosity. |
| `static func setHandleCacheSize(_ n: Int)` | Sets the handle cache size. |
| `static func clearHandleCache()` | Clears the handle cache. |

---

### `AFF4Error`

```swift
public enum AFF4Error: Error {
    case openFailed(String)       // Image could not be opened; C messages folded into the string
    case readFailed(String)       // Read operation failed; C messages folded into the string
    case invalidHandle            // Handle is closed or was never opened
    case messageDrained([String]) // Reserved; not currently thrown by AFF4Image
}
```

---

## Supported Formats

| Format                 | Extension             | Support                          |
| ---------------------- | --------------------- | -------------------------------- |
| AFF4 Standard          | `.aff4`               | Supported                        |
| AFF4 Pre-Standard      | `.af4`                | Not supported (legacy)           |
| Striped / spanned AFF4 | `_1.aff4` + `_2.aff4` | Planned                          |

---

## Bundled Libraries

All dependencies are statically linked as universal fat binaries (arm64 + x86_64). The following are compiled into the package:

| Library     | Version            | Purpose                        |
| ----------- | ------------------ | ------------------------------ |
| c-aff4      | Velocidex/c-aff4   | AFF4 read/write implementation |
| raptor2     | 2.0.16             | RDF/Turtle metadata parsing    |
| OpenSSL     | 3.x                | Hashing and encryption         |
| zlib        | latest             | Deflate compression            |
| lz4         | latest             | LZ4 compression                |
| snappy      | latest             | Snappy compression             |
| uriparser   | latest             | URI parsing                    |

The following macOS system libraries are also linked (no bundling required):

- `libxml2`, `libxslt`, `libiconv` — required by raptor2 for XML/XSLT/GRDDL support
- `libcurl` — required by raptor2 for URI retrieval
- `libc++`, `libpthread` — C++ stdlib and threading

---

## Xcode Integration Note

When integrating into an Xcode project, the `Package.swift` uses `#filePath` for the linker search path to ensure correct resolution in both `swift build` and Xcode Archive contexts:

```swift
// Xcode resolves relative -L paths against build intermediates, not the package root.
// #filePath gives an absolute path that works in both contexts.
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
.unsafeFlags(["-L\(packageRoot)/Sources/Ccaff4"])
```

---

## Building From Source

See the [swift-forensic-playbook](https://github.com/saadtahir-dev/swift-forensic-playbook) for the complete step-by-step guide covering:

- Building all dependencies (OpenSSL, zlib, raptor2, lz4, snappy, uriparser)
- Building c-aff4 as a universal static library
- Creating the SPM package structure

---

## License

MIT — see [LICENSE](./LICENSE)

---

## Related

- [swift-forensic-playbook](https://github.com/saadtahir-dev/swift-forensic-playbook) — Build guides for forensic image libraries as Swift Packages
- [Velocidex/c-aff4](https://github.com/Velocidex/c-aff4) — Upstream c-aff4 library
- [aff4/aff4-cpp-lite](https://github.com/aff4/aff4-cpp-lite) — Lightweight AFF4 reader (also wrapped in the playbook)
