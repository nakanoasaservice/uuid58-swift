# uuid58 for Swift

Swift implementation of
[uuid58](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md):
a fixed 22-character Base58 encoding for 128-bit UUIDs.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  <->  XDY9dmBbcMBXqcRvYw8xJ2
```

- Always exactly 22 characters, using the Bitcoin Base58 alphabet (no `0`,
  `O`, `I`, `l`).
- Sorts in the same order as the UUIDs it encodes, when compared byte by byte.
- Works with Foundation's `UUID`, 16-byte arrays and `Data`, and 128-bit
  values as two `UInt64`s.
- No dependencies besides Foundation. Swift 6.0 or later, on Apple platforms
  and Linux.
- Passes every applicable case in the shared
  [test vectors](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json).

The specification and the implementations in other languages (JavaScript,
Go, Python, Rust, Java) live in
[nakanoasaservice/uuid58](https://github.com/nakanoasaservice/uuid58). This
package has its own repository because Swift Package Manager expects
`Package.swift` at the root of a repository.

## Install

In `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/nakanoasaservice/uuid58-swift.git", from: "0.1.0"),
],
targets: [
  .target(name: "MyApp", dependencies: [
    .product(name: "UUID58", package: "uuid58-swift"),
  ]),
]
```

In Xcode, choose File > Add Package Dependencies and enter the repository
URL.

## Usage

```swift
import UUID58

let s = try uuid58Encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
// "XDY9dmBbcMBXqcRvYw8xJ2"

let u = try uuid58Decode("XDY9dmBbcMBXqcRvYw8xJ2")
// "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"

isUuid58("XDY9dmBbcMBXqcRvYw8xJ2") // true

let id = uuid58() // uuid58 of a new random (version 4) UUID
```

### With Foundation's `UUID`

```swift
let uuid = UUID()
let s = uuid.uuid58String          // never fails
let back = try UUID(uuid58: s)     // back == uuid
```

### API

| Function                                      | Description                                             |
| --------------------------------------------- | ------------------------------------------------------- |
| `uuid58Encode(_: String) throws -> String`    | Encodes a UUID string                                   |
| `uuid58Encode(_: UUID) -> String`             | Encodes a `UUID`                                        |
| `uuid58Encode(bytes:) throws -> String`       | Encodes 16 bytes (any `Collection` of `UInt8`, `Data`)  |
| `uuid58Encode(high:low:) -> String`           | Encodes a 128-bit value given as two `UInt64`s          |
| `uuid58Decode(_:) throws -> String`           | Decodes to a lowercase hyphenated UUID string           |
| `uuid58DecodeUUID(_:) throws -> UUID`         | Decodes to a `UUID`                                     |
| `uuid58DecodeBytes(_:) throws -> [UInt8]`     | Decodes to 16 bytes                                     |
| `uuid58DecodeInteger(_:) throws -> (high:low:)` | Decodes to two `UInt64`s                              |
| `isUuid58(_:) -> Bool`                        | `true` exactly when decoding would succeed              |
| `uuid58() -> String`                          | uuid58 of a new random UUID (not part of the spec)      |
| `UUID(uuid58:)`, `UUID.uuid58String`          | Conveniences on `UUID`                                  |

Bytes are in big-endian (RFC 9562) order, the same order as
`UUID.uuid`.

### Input rules

`uuid58Encode(_: String)` accepts only the hyphenated form
(`f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf`) and 32 hexadecimal digits, in any
letter case. Braces, `urn:uuid:`, whitespace, and misplaced hyphens are
rejected. Note that Foundation's `UUID(uuidString:)` is not used for parsing.

Decoding is case-sensitive and does not trim whitespace. Input is checked
byte by byte in UTF-8, so non-ASCII input is always rejected, even when it
is canonically equivalent to ASCII (for example U+212A KELVIN SIGN and `K`).

### Errors

Every function throws `UUID58Error`, one of the error kinds of the
specification (functions use typed `throws`):

| Case                | Thrown when                                                                          |
| ------------------- | ------------------------------------------------------------------------------------ |
| `.invalidLength`    | The input has the wrong length (22 for uuid58, 32 or 36 for UUIDs, 16 bytes)         |
| `.invalidCharacter` | The input has the right length but a character not allowed in its position           |
| `.overflow`         | (decoding only) The input is well formed but its value is greater than 2^128 − 1     |

```swift
do {
  let uuid = try uuid58Decode(input)
} catch UUID58Error.invalidCharacter {
  // ...
} catch {
  // .invalidLength or .overflow
}
```

## Ordering

Encoded strings sort in the same order as the 128-bit values they encode,
when compared byte by byte (for example `Array(a.utf8)` vs `Array(b.utf8)`,
or a binary collation in a database). Swift's `String` comparison
(`a < b`) is based on Unicode, and coincides with byte order for uuid58
strings because they are ASCII.

## Development

```bash
swift test
```

`Tests/UUID58Tests/vectors.json` is a copy of
[`spec/vectors.json`](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json).
CI fails when the two differ; to update, copy the upstream file and run the
tests.

### Releasing

Swift Package Manager uses Git tags as versions. Tag a commit on `main` with
a plain semantic version and push it:

```bash
git tag 0.1.0 && git push origin 0.1.0
```

## License

MIT License - see the [LICENSE](LICENSE) file for details
