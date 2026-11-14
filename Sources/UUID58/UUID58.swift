import Foundation

// An implementation of the uuid58 specification:
// https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md
//
// All parsing works on the UTF-8 bytes of a string. Swift's `String` and
// `Character` comparisons use Unicode canonical equivalence, which the
// specification forbids (Section 4.1), so they are never used on input.

/// The Base58 alphabet used by uuid58 (the Bitcoin alphabet).
public let uuid58Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

/// The kinds of error defined by the uuid58 specification (Section 7).
public enum UUID58Error: Error, Equatable, Hashable, Sendable {
  /// The input has the wrong length: a uuid58 string that is not 22
  /// characters, a UUID string that is neither 32 nor 36 characters, or a
  /// byte sequence that is not 16 bytes long.
  case invalidLength
  /// The input has the right length but contains a character that is not
  /// allowed in its position.
  case invalidCharacter
  /// The uuid58 string is well formed, but its value is greater than
  /// 2^128 - 1.
  case overflow
}

// MARK: - Encoding

/// Encodes a UUID string as a 22-character uuid58 string.
///
/// Accepts only the hyphenated form (`f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf`)
/// and 32 hexadecimal digits, in any letter case. Braces, `urn:uuid:`,
/// whitespace, and misplaced hyphens are rejected.
public func uuid58Encode(_ uuid: String) throws(UUID58Error) -> String {
  encodeBytes(try parseUUIDString(uuid))
}

/// Encodes a `UUID` as a 22-character uuid58 string. Never fails.
public func uuid58Encode(_ uuid: UUID) -> String {
  encodeBytes(bytes(of: uuid))
}

/// Encodes 16 bytes, in big-endian (RFC 9562) order, as a 22-character
/// uuid58 string.
///
/// - Throws: `UUID58Error.invalidLength` if `bytes` is not exactly 16 bytes
///   long.
public func uuid58Encode<C: Collection>(bytes: C) throws(UUID58Error) -> String
where C.Element == UInt8 {
  guard bytes.count == 16 else { throw .invalidLength }
  return encodeBytes(Array(bytes))
}

/// Encodes a 128-bit value, given as its high and low 64 bits, as a
/// 22-character uuid58 string. Never fails.
public func uuid58Encode(high: UInt64, low: UInt64) -> String {
  var b = [UInt8](repeating: 0, count: 16)
  for i in 0..<8 {
    b[i] = UInt8(truncatingIfNeeded: high >> (56 - 8 * UInt64(i)))
    b[8 + i] = UInt8(truncatingIfNeeded: low >> (56 - 8 * UInt64(i)))
  }
  return encodeBytes(b)
}

// MARK: - Decoding

/// Decodes a uuid58 string to a lowercase hyphenated UUID string.
public func uuid58Decode(_ uuid58: String) throws(UUID58Error) -> String {
  formatUUID(try decodeToBytes(uuid58))
}

/// Decodes a uuid58 string to a `UUID`.
public func uuid58DecodeUUID(_ uuid58: String) throws(UUID58Error) -> UUID {
  let b = try decodeToBytes(uuid58)
  return UUID(
    uuid: (
      b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
      b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
    ))
}

/// Decodes a uuid58 string to 16 bytes in big-endian (RFC 9562) order.
public func uuid58DecodeBytes(_ uuid58: String) throws(UUID58Error) -> [UInt8] {
  try decodeToBytes(uuid58)
}

/// Decodes a uuid58 string to a 128-bit value, as its high and low 64 bits.
public func uuid58DecodeInteger(_ uuid58: String) throws(UUID58Error) -> (
  high: UInt64, low: UInt64
) {
  let b = try decodeToBytes(uuid58)
  var high: UInt64 = 0
  var low: UInt64 = 0
  for i in 0..<8 {
    high = high << 8 | UInt64(b[i])
    low = low << 8 | UInt64(b[8 + i])
  }
  return (high, low)
}

// MARK: - Validation and generation

/// Returns `true` exactly when `uuid58Decode` would succeed for the string.
public func isUuid58(_ uuid58: String) -> Bool {
  (try? decodeToBytes(uuid58)) != nil
}

/// Returns the uuid58 encoding of a new random (version 4) UUID.
///
/// Generation is not part of the uuid58 specification; this is a
/// convenience.
public func uuid58() -> String {
  uuid58Encode(UUID())
}

extension UUID {
  /// Creates a UUID from a uuid58 string.
  public init(uuid58: String) throws(UUID58Error) {
    self = try uuid58DecodeUUID(uuid58)
  }

  /// The uuid58 encoding of this UUID.
  public var uuid58String: String {
    uuid58Encode(self)
  }
}

// MARK: - Implementation

private let alphabetBytes = Array(uuid58Alphabet.utf8)

/// Maps a byte to its Base58 digit, or -1 for bytes outside the alphabet.
private let digitTable: [Int8] = {
  var table = [Int8](repeating: -1, count: 256)
  for (i, c) in alphabetBytes.enumerated() {
    table[Int(c)] = Int8(i)
  }
  return table
}()

/// Maps a byte to its hexadecimal value, or -1 for non-hex bytes.
private let hexTable: [Int8] = {
  var table = [Int8](repeating: -1, count: 256)
  for (i, c) in "0123456789abcdef".utf8.enumerated() {
    table[Int(c)] = Int8(i)
  }
  for (i, c) in "ABCDEF".utf8.enumerated() {
    table[Int(c)] = Int8(10 + i)
  }
  return table
}()

private let hexDigits = Array("0123456789abcdef".utf8)
private let hyphen = UInt8(ascii: "-")

private func bytes(of uuid: UUID) -> [UInt8] {
  let u = uuid.uuid
  return [
    u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7,
    u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15,
  ]
}

/// Encodes 16 big-endian bytes as 22 Base58 digits (SPEC.md Section 3.1).
private func encodeBytes(_ input: [UInt8]) -> String {
  var value = input
  var out = [UInt8](repeating: alphabetBytes[0], count: 22)
  // Repeated long division of the 128-bit value by 58, least significant
  // digit first. 22 digits always suffice, because 58^22 > 2^128.
  for i in stride(from: 21, through: 0, by: -1) {
    var remainder = 0
    for j in 0..<16 {
      let acc = remainder << 8 | Int(value[j])
      value[j] = UInt8(acc / 58)
      remainder = acc % 58
    }
    out[i] = alphabetBytes[remainder]
  }
  return String(decoding: out, as: UTF8.self)
}

/// Decodes a uuid58 string to 16 big-endian bytes (SPEC.md Section 4).
private func decodeToBytes(_ s: String) throws(UUID58Error) -> [UInt8] {
  // Length is measured in UTF-8 bytes (SPEC.md Section 4.1).
  let input = Array(s.utf8)
  guard input.count == 22 else { throw .invalidLength }

  var digits = [Int](repeating: 0, count: 22)
  for (i, c) in input.enumerated() {
    let d = digitTable[Int(c)]
    guard d >= 0 else { throw .invalidCharacter }
    digits[i] = Int(d)
  }

  // value = value * 58 + digit, on 16 big-endian bytes. A carry out of the
  // most significant byte means the value does not fit in 128 bits.
  var value = [UInt8](repeating: 0, count: 16)
  for d in digits {
    var carry = d
    for j in stride(from: 15, through: 0, by: -1) {
      let acc = Int(value[j]) * 58 + carry
      value[j] = UInt8(truncatingIfNeeded: acc)
      carry = acc >> 8
    }
    guard carry == 0 else { throw .overflow }
  }
  return value
}

/// Parses a UUID string in one of the two forms of SPEC.md Section 5.1.
private func parseUUIDString(_ s: String) throws(UUID58Error) -> [UInt8] {
  let input = Array(s.utf8)
  let hyphenated: Bool
  switch input.count {
  case 32: hyphenated = false
  case 36: hyphenated = true
  default: throw .invalidLength
  }

  var nibbles = [UInt8]()
  nibbles.reserveCapacity(32)
  for (i, c) in input.enumerated() {
    if hyphenated && (i == 8 || i == 13 || i == 18 || i == 23) {
      guard c == hyphen else { throw .invalidCharacter }
      continue
    }
    let v = hexTable[Int(c)]
    guard v >= 0 else { throw .invalidCharacter }
    nibbles.append(UInt8(v))
  }

  var out = [UInt8](repeating: 0, count: 16)
  for i in 0..<16 {
    out[i] = nibbles[2 * i] << 4 | nibbles[2 * i + 1]
  }
  return out
}

/// Formats 16 bytes as a lowercase hyphenated UUID string (Section 5.2).
private func formatUUID(_ b: [UInt8]) -> String {
  var out = [UInt8]()
  out.reserveCapacity(36)
  for (i, byte) in b.enumerated() {
    if i == 4 || i == 6 || i == 8 || i == 10 {
      out.append(hyphen)
    }
    out.append(hexDigits[Int(byte >> 4)])
    out.append(hexDigits[Int(byte & 0x0f)])
  }
  return String(decoding: out, as: UTF8.self)
}
