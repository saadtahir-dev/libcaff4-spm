//
//  AFF4Image.swift
//  Libcaff4
//
//  Created by Saad Tahir on 13/05/2026.
//   -- GitHub   : https://github.com/saadtahir-dev
//   -- LinkedIn : https://www.linkedin.com/in/saadtahir-dev
//

import Ccaff4
import Darwin
import Foundation

/// Represents an open AFF4 image.
///
/// - Important: The underlying `AFF4_Handle*` is not MT-safe. This wrapper serializes
///   access internally so it can be used from async contexts without crashing.
public final class AFF4Image: @unchecked Sendable {
    /// The path used to open this image.
    public let path: String

    /// The size of the image in bytes.
    public let size: UInt64

    private let lock = NSLock()
    private var handle: OpaquePointer?
    private let maxChunkSize: Int

    /// Opens an AFF4 image at `path`.
    ///
    /// - Parameters:
    ///   - path: Path to an `.aff4` container on disk.
    ///   - maxChunkSize: Maximum chunk size for reads (defaults to 1 MiB).
    /// - Throws: `AFF4Error.openFailed` if the underlying handle could not be opened.
    public init(path: String, maxChunkSize: Int = 1024 * 1024) throws {
        self.path = path
        self.maxChunkSize = max(1, maxChunkSize)

        // Preflight: verify the file is visible to this process.
        do {
            _ = try FileManager.default.attributesOfItem(atPath: path)
        } catch {
            if let nsError = error as NSError? {
                throw AFF4Error.openFailed(
                    "attributesOfItem failed for path=\(path) (domain=\(nsError.domain) code=\(nsError.code)): \(nsError.localizedDescription)"
                )
            }
            throw AFF4Error.openFailed("attributesOfItem failed for path=\(path): \(error.localizedDescription)")
        }

        var msg: UnsafeMutablePointer<AFF4_Message>? = nil
        errno = 0
        let opened: OpaquePointer? = path.withCString { cstr in
            AFF4_open(cstr, &msg)
        }
        let openErrno = errno
        let openMessages = AFF4MessageHelper.drainMessages(msg)

        guard let opened else {
            let errnoDescription = String(cString: strerror(openErrno))
            let messageDetail = openMessages
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n")

            let detail: String
            if !messageDetail.isEmpty {
                detail = messageDetail
            } else {
                detail = "AFF4_open failed for path=\(path) (errno=\(openErrno): \(errnoDescription))"
            }

            throw AFF4Error.openFailed(detail)
        }

        // Compute size immediately and cache it for non-throwing access.
        var msg2: UnsafeMutablePointer<AFF4_Message>? = nil
        let computedSize = AFF4_object_size(opened, &msg2)
        _ = AFF4MessageHelper.drainMessages(msg2)

        self.size = computedSize
        self.handle = opened
    }

    deinit {
        close()
    }

    /// Reads `length` bytes starting at `offset`.
    ///
    /// This method reads in chunks to support large images efficiently.
    ///
    /// - Parameters:
    ///   - offset: Byte offset into the image.
    ///   - length: Number of bytes to read.
    /// - Returns: A `Data` buffer containing the bytes read.
    /// - Throws: `AFF4Error.invalidHandle` if closed, `AFF4Error.readFailed` on read errors.
    public func read(offset: UInt64, length: Int) throws -> Data {
        if length < 0 {
            throw AFF4Error.readFailed("length must be >= 0")
        }
        if length == 0 {
            return Data()
        }
        if offset > size {
            throw AFF4Error.readFailed("offset \(offset) is beyond end of image (size \(size))")
        }

        let available = size - offset
        let requested = UInt64(length)
        let toRead64 = min(available, requested)
        if toRead64 == 0 {
            return Data()
        }

        var result = Data()
        result.reserveCapacity(Int(toRead64))

        var remaining = Int(toRead64)
        var currentOffset = offset

        while remaining > 0 {
            let chunkLen = min(remaining, maxChunkSize)
            var chunk = Data(count: chunkLen)

            let (bytesRead, drainedMessages): (Int, [String]) = try lock.withLock {
                guard let h = handle else { throw AFF4Error.invalidHandle }

                var msg: UnsafeMutablePointer<AFF4_Message>? = nil
                let readCount = chunk.withUnsafeMutableBytes { rawBuf -> Int in
                    guard let base = rawBuf.baseAddress else { return -1 }
                    let n = AFF4_read(h, currentOffset, base, chunkLen, &msg)
                    return Int(n)
                }

                let messages = AFF4MessageHelper.drainMessages(msg)
                return (readCount, messages)
            }

            if bytesRead < 0 {
                let detail = drainedMessages.isEmpty ? "AFF4_read returned \(bytesRead)" : drainedMessages.joined(separator: "\n")
                throw AFF4Error.readFailed(detail)
            }
            if bytesRead == 0 {
                break
            }

            if bytesRead < chunkLen {
                chunk.count = bytesRead
            }
            result.append(chunk)

            remaining -= bytesRead
            currentOffset += UInt64(bytesRead)

            if bytesRead < chunkLen {
                // Short read (EOF or sparse region). Stop; validate below.
                break
            }
        }

        // If we didn't reach the expected end and we're still within the object, treat as error.
        if result.count < Int(toRead64), (offset + UInt64(result.count)) < size {
            throw AFF4Error.readFailed("short read: expected \(toRead64) bytes, got \(result.count)")
        }

        return result
    }

    /// Closes the image handle. Safe to call multiple times.
    public func close() {
        lock.lock()
        defer { lock.unlock() }

        guard let h = handle else { return }
        defer { handle = nil }

        var msg: UnsafeMutablePointer<AFF4_Message>? = nil
        _ = AFF4_close(h, &msg)
        _ = AFF4MessageHelper.drainMessages(msg)
    }
}
