import XCTest
import IOKit.pwr_mgt
@testable import PilotCore

final class PilotCoreTests: XCTestCase {
    // Catches unbounded, non-finite or malformed hold durations.
    func testDurationRejectsUnsafeValues() throws {
        for value in ["0", "-1", "61", "nan", "inf", "hello"] {
            XCTAssertThrowsError(try holdDuration(value), value)
        }
        XCTAssertEqual(try holdDuration("0.1"), 0.1)
        XCTAssertEqual(try holdDuration("60"), 60)
    }

    // Catches a permission failure accidentally treated as authorization.
    func testAutomationRequiresSuccessfulStatus() throws {
        try requireAutomationPermission(0)
        for status: Int32 in [-1743, -1744, -600] {
            XCTAssertThrowsError(try requireAutomationPermission(status)) {
                XCTAssertEqual($0 as? PilotError, .automation(status))
            }
        }
    }

    // Catches missing create/release and duplicate-start ownership leaks.
    func testThreeRealAssertionCycles() throws {
        let assertion = PowerAssertion()
        for _ in 0..<3 {
            try assertion.start()
            let id = try XCTUnwrap(assertion.id)
            XCTAssertNotNil(IOPMAssertionCopyProperties(id))
            try assertion.start()
            XCTAssertEqual(assertion.id, id)
            try assertion.stop()
            XCTAssertNil(IOPMAssertionCopyProperties(id))
            XCTAssertNil(assertion.id)
            try assertion.stop()
        }
    }

    // Catches a leaked assertion when its owner leaves scope.
    func testOwnerDeinitReleasesAssertion() throws {
        var owner: PowerAssertion? = PowerAssertion()
        try owner?.start()
        let id = try XCTUnwrap(owner?.id)
        owner = nil
        XCTAssertNil(IOPMAssertionCopyProperties(id))
    }
}
