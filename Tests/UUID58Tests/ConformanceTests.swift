import Foundation
import Testing

@testable import UUID58

// Conformance tests against the language-neutral test vectors of the uuid58
// specification (SPEC.md, Section 8). `vectors.json` is a copy of
// spec/vectors.json from https://github.com/nakanoasaservice/uuid58.

struct Vectors: Decodable {
  struct Roundtrip: Decodable, CustomTestStringConvertible, Sendable {
    let description: String
    let uuid: String
    let uuid58: String
    var testDescription: String { description }
  }
  struct Valid: Decodable, CustomTestStringConvertible, Sendable {
    let description: String
    let input: String
    let output: String
    var testDescription: String { description }
  }
  struct Invalid: Decodable, CustomTestStringConvertible, Sendable {
    let description: String
    let input: String
    let errors: [String]
    var testDescription: String { description }
  }
  struct InvalidBytes: Decodable, CustomTestStringConvertible, Sendable {
    let description: String
    let bytes: String
    let errors: [String]
    var testDescription: String { description }
  }
  struct Encode: Decodable {
    let valid: [Valid]
    let invalid: [Invalid]
    let invalid_bytes: [InvalidBytes]
  }
  struct Decode: Decodable {
    let invalid: [Invalid]
  }

  let spec_version: String
  let alphabet: String
  let roundtrip: [Roundtrip]
  let encode: Encode
  let decode: Decode

  static let shared: Vectors = {
    let url = Bundle.module.url(forResource: "vectors", withExtension: "json")!
    let data = try! Data(contentsOf: url)
    return try! JSONDecoder().decode(Vectors.self, from: data)
  }()
}

func kindName(_ error: UUID58Error) -> String {
  switch error {
  case .invalidLength: "invalid_length"
  case .invalidCharacter: "invalid_character"
  case .overflow: "overflow"
  }
}

func hexBytes(_ hex: String) -> [UInt8] {
  let chars = Array(hex.utf8)
  return stride(from: 0, to: chars.count, by: 2).map {
    UInt8(String(decoding: chars[$0..<$0 + 2], as: UTF8.self), radix: 16)!
  }
}

/// Runs `body` and returns the kind of `UUID58Error` it throws, or nil.
/// (Untyped `throws`: typed-throws function types need macOS 15 at runtime.)
func thrownKind<T>(_ body: () throws -> T) -> String? {
  do {
    _ = try body()
    return nil
  } catch let error as UUID58Error {
    return kindName(error)
  } catch {
    return "unexpected error: \(error)"
  }
}

@Suite("spec vectors")
struct ConformanceTests {
  @Test func alphabet() {
    #expect(uuid58Alphabet == Vectors.shared.alphabet)
    #expect(Vectors.shared.spec_version.hasPrefix("1."))
  }

  @Test(arguments: Vectors.shared.roundtrip)
  func roundtrip(_ c: Vectors.Roundtrip) throws {
    #expect(try uuid58Encode(c.uuid) == c.uuid58)
    #expect(try uuid58Decode(c.uuid58) == c.uuid)
    #expect(isUuid58(c.uuid58))

    // Bytes, in big-endian order, derived from `uuid` (SPEC.md 8.1).
    let bytes = hexBytes(c.uuid.replacingOccurrences(of: "-", with: ""))
    #expect(try uuid58Encode(bytes: bytes) == c.uuid58)
    #expect(try uuid58Encode(bytes: Data(bytes)) == c.uuid58)
    #expect(try uuid58DecodeBytes(c.uuid58) == bytes)

    // High and low 64 bits.
    let high = bytes[0..<8].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    let low = bytes[8..<16].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    #expect(uuid58Encode(high: high, low: low) == c.uuid58)
    let decoded = try uuid58DecodeInteger(c.uuid58)
    #expect(decoded.high == high && decoded.low == low)

    // Foundation's UUID, compared with `uuid` rather than only round-tripped,
    // so that a byte-order mistake cannot hide.
    let native = try #require(UUID(uuidString: c.uuid))
    #expect(uuid58Encode(native) == c.uuid58)
    #expect(native.uuid58String == c.uuid58)
    #expect(try uuid58DecodeUUID(c.uuid58).uuidString.lowercased() == c.uuid)
    #expect(try UUID(uuid58: c.uuid58) == native)
  }

  @Test(arguments: Vectors.shared.encode.valid)
  func encodeValid(_ c: Vectors.Valid) throws {
    #expect(try uuid58Encode(c.input) == c.output)
  }

  // Includes the vectors marked `lenient`: they are accepted only by
  // JavaScript 1.x (SPEC.md 9.1) and must be rejected here.
  @Test(arguments: Vectors.shared.encode.invalid)
  func encodeInvalid(_ c: Vectors.Invalid) {
    let kind = thrownKind { try uuid58Encode(c.input) }
    #expect(kind != nil, "accepted \(c.input.debugDescription)")
    if let kind {
      #expect(c.errors.contains(kind), "got \(kind)")
    }
  }

  @Test(arguments: Vectors.shared.encode.invalid_bytes)
  func encodeInvalidBytes(_ c: Vectors.InvalidBytes) {
    let bytes = hexBytes(c.bytes)
    let kind = thrownKind { try uuid58Encode(bytes: bytes) }
    #expect(kind != nil)
    if let kind {
      #expect(c.errors.contains(kind), "got \(kind)")
    }
  }

  @Test(arguments: Vectors.shared.decode.invalid)
  func decodeInvalid(_ c: Vectors.Invalid) {
    let kinds = [
      thrownKind { try uuid58Decode(c.input) },
      thrownKind { try uuid58DecodeBytes(c.input) },
      thrownKind { try uuid58DecodeUUID(c.input) },
      thrownKind { try uuid58DecodeInteger(c.input) },
    ]
    for kind in kinds {
      #expect(kind != nil, "accepted \(c.input.debugDescription)")
      if let kind {
        #expect(c.errors.contains(kind), "got \(kind)")
      }
    }
    #expect(!isUuid58(c.input))
  }
}
