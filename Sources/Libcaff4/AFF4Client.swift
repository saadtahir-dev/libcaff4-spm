//
//  AFF4Client.swift
//  Libcaff4
//
//  Created by Saad Tahir on 13/05/2026.
//   -- GitHub   : https://github.com/saadtahir-dev
//   -- LinkedIn : https://www.linkedin.com/in/saadtahir-dev
//

import Ccaff4
import Foundation

/// Static utilities for interacting with libaff4 configuration and metadata.
public struct AFF4Client {
    /// Returns the libaff4 version string.
    public static func version() -> String {
        let ptr = AFF4_version()
        return ptr.map { String(cString: $0) } ?? ""
    }

    /// Sets the global libaff4 logging verbosity.
    public static func setVerbosity(_ level: AFF4_LOG_LEVEL) {
        AFF4_set_verbosity(level)
    }

    /// Sets the maximum number of handles to retain in the libaff4 handle cache.
    public static func setHandleCacheSize(_ n: Int) {
        AFF4_set_handle_cache_size(n)
    }

    /// Clears the libaff4 handle cache, freeing all cached handles.
    public static func clearHandleCache() {
        AFF4_clear_handle_cache()
    }
}

enum AFF4MessageHelper {
    /// Drains and returns messages from a linked `AFF4_Message*` list.
    ///
    /// This function always calls `AFF4_free_messages` if `msg` is non-nil.
    static func drainMessages(_ msg: UnsafeMutablePointer<AFF4_Message>?) -> [String] {
        guard let msg else { return [] }
        defer { AFF4_free_messages(msg) }

        var out: [String] = []
        out.reserveCapacity(4)

        var cursor: UnsafeMutablePointer<AFF4_Message>? = msg
        while let node = cursor {
            if let cstr = node.pointee.message {
                out.append(String(cString: cstr))
            }
            cursor = node.pointee.next
        }

        return out
    }
}
