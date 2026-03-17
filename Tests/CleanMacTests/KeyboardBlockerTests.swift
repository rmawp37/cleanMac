import ApplicationServices
import XCTest
@testable import CleanMac

final class KeyboardBlockerTests: XCTestCase {
    func testBlockedEventMaskIncludesSystemDefinedEvents() {
        let mask = KeyboardBlocker.blockedEventMask()
        let systemDefinedBit = CGEventMask(1 << systemDefinedEventTypeRawValue)

        XCTAssertNotEqual(mask & systemDefinedBit, 0)
    }

    func testShouldBlockReturnsTrueForMediaKeyEventType() {
        XCTAssertTrue(KeyboardBlocker.shouldBlock(eventType: systemDefinedEventType))
    }

    func testShouldBlockReturnsTrueForRegularKeyboardEvents() {
        XCTAssertTrue(KeyboardBlocker.shouldBlock(eventType: .keyDown))
        XCTAssertTrue(KeyboardBlocker.shouldBlock(eventType: .keyUp))
        XCTAssertTrue(KeyboardBlocker.shouldBlock(eventType: .flagsChanged))
    }

    func testShouldBlockReturnsFalseForMouseMovement() {
        XCTAssertFalse(KeyboardBlocker.shouldBlock(eventType: .mouseMoved))
    }

    func testCapsLockMappingIsAddedWithoutDroppingOtherMappings() {
        let existingMappings = [
            HIDKeyMapping(
                HIDKeyboardModifierMappingSrc: 0x700000004,
                HIDKeyboardModifierMappingDst: 0x700000005
            )
        ]

        let mergedMappings = CapsLockRemapper.mergedMappingsForLock(existingMappings: existingMappings)

        XCTAssertEqual(mergedMappings.count, 2)
        XCTAssertTrue(mergedMappings.contains(existingMappings[0]))
        XCTAssertTrue(mergedMappings.contains(
            HIDKeyMapping(
                HIDKeyboardModifierMappingSrc: CapsLockRemapper.capsLockUsage,
                HIDKeyboardModifierMappingDst: CapsLockRemapper.f18Usage
            )
        ))
    }

    func testCapsLockPayloadRoundTripsThroughJSON() throws {
        let mappings = [
            HIDKeyMapping(
                HIDKeyboardModifierMappingSrc: CapsLockRemapper.capsLockUsage,
                HIDKeyboardModifierMappingDst: CapsLockRemapper.f18Usage
            )
        ]

        let payload = try CapsLockRemapper.payloadString(for: mappings)
        let decodedMappings = try CapsLockRemapper.parseMappings(from: payload)

        XCTAssertEqual(decodedMappings, mappings)
    }

    func testParseMappingsHandlesNullOutput() throws {
        XCTAssertEqual(try CapsLockRemapper.parseMappings(from: "(null)"), [])
    }

    func testParseMappingsHandlesEmptyLegacyOutput() throws {
        XCTAssertEqual(try CapsLockRemapper.parseMappings(from: "(\n)"), [])
        XCTAssertEqual(try CapsLockRemapper.parseMappings(from: "UserKeyMapping:(\n)"), [])
    }

    func testParseMappingsHandlesLegacyHidutilOutput() throws {
        let output = """
        UserKeyMapping:(
                {
                HIDKeyboardModifierMappingDst = 30064771181;
                HIDKeyboardModifierMappingSrc = 30064771129;
            }
        )
        """

        let mappings = try CapsLockRemapper.parseMappings(from: output)

        XCTAssertEqual(
            mappings,
            [
                HIDKeyMapping(
                    HIDKeyboardModifierMappingSrc: CapsLockRemapper.capsLockUsage,
                    HIDKeyboardModifierMappingDst: CapsLockRemapper.f18Usage
                )
            ]
        )
    }
}