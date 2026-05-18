//
//  AFF4Error.swift
//  Libcaff4
//
//  Created by Saad Tahir on 13/05/2026.
//   -- GitHub   : https://github.com/saadtahir-dev
//   -- LinkedIn : https://www.linkedin.com/in/saadtahir-dev
//

import Foundation

/// Typed errors thrown by the Libcaff4 Swift wrapper.
public enum AFF4Error: Error, LocalizedError, Sendable, Equatable {
    /// The image could not be opened. The associated value is an error detail string.
    case openFailed(String)

    /// A read operation failed. The associated value is an error detail string.
    case readFailed(String)

    /// The underlying AFF4 handle is invalid (closed or never opened).
    case invalidHandle

    /// Messages were drained from `AFF4_Message*` and surfaced to the caller.
    case messageDrained([String])

    public var errorDescription: String? {
        switch self {
        case .openFailed(let detail):
            return detail.isEmpty ? "Failed to open AFF4 image." : "Failed to open AFF4 image: \(detail)"
            
        case .readFailed(let detail):
            return detail.isEmpty ? "Failed to read from AFF4 image." : "Failed to read from AFF4 image: \(detail)"
            
        case .invalidHandle:
            return "Invalid AFF4 handle (image is closed)."
            
        case .messageDrained(let messages):
            return messages.isEmpty ? "AFF4 message list drained." : messages.joined(separator: "\n")
        }
    }
}
