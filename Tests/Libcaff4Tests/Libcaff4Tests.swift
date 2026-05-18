//
//  Libcaff4Tests.swift
//  Libcaff4
//
//  Created by Saad Tahir on May 13, 2026.
//   -- GitHub   : https://github.com/saadtahir-dev
//   -- LinkedIn : https://www.linkedin.com/in/saadtahir-dev
//

import XCTest
import Libcaff4
import Ccaff4

final class Libcaff4Tests: XCTestCase {

    private func imagePath(_ name: String) throws -> String {
        guard let bundleURL = Bundle.module.resourceURL else {
            throw XCTSkip("Bundle resources not available")
        }
        let url = bundleURL
            .appendingPathComponent("TestImages")
            .appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Test image not found: \(name)")
        }
        return url.path
    }

    func testVersion() {
        let v = AFF4Client.version()
        XCTAssertFalse(v.isEmpty)
        print("libaff4 version: \(v)")
    }

    func testSetVerbosity() {
        AFF4Client.setVerbosity(AFF4_LOG_LEVEL_ERROR)
    }

    func testOpenReferenceImageAndSize() throws {
        AFF4Client.setVerbosity(AFF4_LOG_LEVEL_OFF)
        let img = try AFF4Image(path: imagePath("Base-Linear.aff4"))
        XCTAssertGreaterThan(img.size, 0)
        print("Image size: \(img.size)")
        img.close()
    }

    func testReadFirstBytes() throws {
        AFF4Client.setVerbosity(AFF4_LOG_LEVEL_OFF)
        let img = try AFF4Image(path: imagePath("Base-Linear.aff4"))
        let data = try img.read(offset: 0, length: 64)
        XCTAssertEqual(data.count, min(64, Int(img.size)))
        img.close()
    }

    func testChunkedReadLargeRange() throws {
        AFF4Client.setVerbosity(AFF4_LOG_LEVEL_OFF)
        let img = try AFF4Image(path: imagePath("Base-Linear.aff4"), maxChunkSize: 256 * 1024)
        let requestLen = 2 * 1024 * 1024
        let data = try img.read(offset: 0, length: requestLen)
        XCTAssertEqual(data.count, min(requestLen, Int(img.size)))
        img.close()
    }

    func testCloseIsIdempotent() throws {
        AFF4Client.setVerbosity(AFF4_LOG_LEVEL_OFF)
        let img = try AFF4Image(path: imagePath("Base-Linear.aff4"))
        img.close()
        img.close()
        XCTAssertThrowsError(try img.read(offset: 0, length: 1)) { err in
            XCTAssertEqual(err as? AFF4Error, .invalidHandle)
        }
    }
}
