import Foundation
import Testing

@testable import UUID58

@Suite("uuid58")
struct UUID58Tests {
  @Test func readmeExample() throws {
    #expect(try uuid58Encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf") == "XDY9dmBbcMBXqcRvYw8xJ2")
    #expect(try uuid58Decode("XDY9dmBbcMBXqcRvYw8xJ2") == "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
  }

  @Test func generatedValuesAreValid() throws {
    for _ in 0..<100 {
      let id = uuid58()
      #expect(id.utf8.count == 22)
      #expect(isUuid58(id))
      let uuid = try UUID(uuid58: id)
      #expect(uuid.uuid58String == id)
    }
  }

  @Test func errorsAreTyped() {
    #expect(throws: UUID58Error.invalidLength) { try uuid58Decode("short") }
    #expect(throws: UUID58Error.invalidCharacter) { try uuid58Decode("0000000000000000000000") }
    #expect(throws: UUID58Error.overflow) { try uuid58Decode("zzzzzzzzzzzzzzzzzzzzzz") }
    #expect(throws: UUID58Error.invalidLength) { try uuid58Encode(bytes: [UInt8](repeating: 0, count: 15)) }
  }

  // Swift's String equality uses Unicode canonical equivalence. Parsing must
  // not: these inputs are canonically equivalent to nothing valid, but make
  // sure precomposed and decomposed forms are both rejected (SPEC.md 4.1).
  @Test(arguments: [
    "XDY9dmBbcMBXqcRvYw8xJ\u{E9}",  // é, precomposed (22 characters)
    "XDY9dmBbcMBXqcRvYw8xJe\u{301}",  // e + combining acute
    "XDY9dmBbcMBXqcRvYw8x\u{212A}2",  // KELVIN SIGN in place of a letter
    "XDY9dmBbcMBXqcRvYw8xJ\u{FF12}",  // FULLWIDTH DIGIT TWO
  ])
  func nonASCIIIsRejected(_ input: String) {
    #expect(throws: UUID58Error.self) { try uuid58Decode(input) }
    #expect(!isUuid58(input))
  }

  @Test(arguments: [
    "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfa\u{FF46}",  // FULLWIDTH f
    "f4b247fd\u{2010}1f87-45d4-aa06-1c6fc0a8dfaf",  // HYPHEN U+2010
    "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfa\u{0661}",  // ARABIC-INDIC DIGIT ONE
  ])
  func nonASCIIUUIDIsRejected(_ input: String) {
    #expect(throws: UUID58Error.self) { try uuid58Encode(input) }
  }

  // Strings built from ill-formed UTF-8 are repaired with U+FFFD by Swift,
  // which is non-ASCII and must be rejected.
  @Test func repairedIllFormedInputIsRejected() {
    var bytes = Array("XDY9dmBbcMBXqcRvYw8xJ2".utf8)
    bytes[21] = 0xFF
    let s = String(decoding: bytes, as: UTF8.self)
    #expect(throws: UUID58Error.self) { try uuid58Decode(s) }
  }

  @Test func sortOrderMatchesNumericOrder() throws {
    let values: [(UInt64, UInt64)] = [
      (0, 0), (0, 1), (0, 57), (0, 58), (0, UInt64.max), (1, 0),
      (UInt64.max >> 1, UInt64.max), (UInt64.max, UInt64.max - 1), (UInt64.max, UInt64.max),
    ]
    let encoded = values.map { uuid58Encode(high: $0.0, low: $0.1) }
    // Compare by UTF-8 bytes, as SPEC.md 3.2 requires.
    for (a, b) in zip(encoded, encoded.dropFirst()) {
      #expect(Array(a.utf8).lexicographicallyPrecedes(Array(b.utf8)))
    }
  }
}
