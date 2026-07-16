<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/vapor/multipart-kit/assets/1130717/4b3aed4e-2b18-4689-80c8-d31ccf169947">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/vapor/multipart-kit/assets/1130717/5c60750b-ef11-4137-9f9e-917ebcc49ca6">
  <img src="https://github.com/vapor/multipart-kit/assets/1130717/5c60750b-ef11-4137-9f9e-917ebcc49ca6" height="96" alt="MultipartKit">
</picture> 
<br>
<br>
<a href="https://api.vapor.codes/multipartkit"><img src="https://design.vapor.codes/images/readthedocs.svg" alt="Documentation"></a>
<a href="https://discord.gg/vapor"><img src="https://design.vapor.codes/images/discordchat.svg" alt="Team Chat"></a>
<a href="LICENSE"><img src="https://design.vapor.codes/images/mitlicense.svg" alt="MIT License"></a>
<a href="https://github.com/vapor/multipart-kit/actions/workflows/test.yml"><img src="https://img.shields.io/github/actions/workflow/status/vapor/multipart-kit/test.yml?event=push&style=plastic&logo=github&label=tests&logoColor=%23ccc" alt="Continuous Integration"></a>
<a href="https://codecov.io/github/vapor/multipart-kit"><img src="https://img.shields.io/codecov/c/github/vapor/multipart-kit?style=plastic&logo=codecov&label=Codecov&token=yDzzHja8lt"></a>
<a href="https://swift.org"><img src="https://design.vapor.codes/images/swift61up.svg" alt="Swift 6.1+"></a>
</p>

🏞 Multipart parser and serializer with `Codable` support for Multipart Form Data.

### Installation

Use the SPM string to easily include the dependency in your `Package.swift` file.

Add MultipartKit to your package dependencies:

```swift
dependencies: [
    // ...
    .package(url: "https://github.com/vapor/multipart-kit.git", from: "5.0.0-alpha.5"),
]
```

Add MultipartKit to your target's dependencies:

```swift
targets: [
    .target(name: "MyAppTarget", dependencies: [
        // ...
        .product(name: "MultipartKit", package: "multipart-kit"),
    ])
]
```

### Supported Platforms

MultipartKit requires Swift 6.1 or later and supports the following platforms:

- All Linux distributions supported by Swift 6.1+
- macOS 10.15+, iOS 13+, tvOS 13+, watchOS 6+, visionOS 1+

## Overview

MultipartKit is a multipart parsing and serializing library. It provides `Codable` support for the special case of the `multipart/form-data` media type through a `FormDataEncoder` and `FormDataDecoder`. Parsing and serialization are also exposed as `AsyncSequence`s, so large messages can be streamed without ever being held in memory in full.

### Multipart Form Data

Let's define a `Codable` type and choose a boundary used to separate the multipart parts.

```swift
struct User: Codable {
    let name: String
    let email: String
}
let user = User(name: "Ed", email: "ed@example.com")
let boundary = "abc123"
```

We can encode this instance of our type using a `FormDataEncoder`.

```swift
let encoded = try FormDataEncoder().encode(user, boundary: boundary)
```

The output then looks like this.
```
--abc123
Content-Disposition: form-data; name="name"

Ed
--abc123
Content-Disposition: form-data; name="email"

ed@example.com
--abc123--
```

In order to _decode_ this message we feed this output and the same boundary to a `FormDataDecoder` and we get back an identical instance to the one we started with.

```swift
let decoded = try FormDataDecoder().decode(User.self, from: encoded, boundary: boundary)
```

`encode` returns a `String` above, but it can produce any `MultipartPartBodyElement`, or append into a buffer you already own.

```swift
// Encode into a body type of your choosing.
let bytes: [UInt8] = try FormDataEncoder().encode(user, boundary: boundary)

// Or append into an existing buffer.
var buffer: [UInt8] = []
try FormDataEncoder().encode(user, boundary: boundary, into: &buffer)
```

Likewise, `FormDataDecoder` decodes from a `String` or from any `MultipartPartBodyElement`.

### A note on `null`

As there is no standard defined for how to represent `null` in Multipart (unlike, for instance, JSON), `FormDataEncoder` and `FormDataDecoder` do not support encoding or decoding `null` respectively.

### Nesting and Collections

Nested structures can be represented by naming the parts such that they describe a path using square brackets to denote contained properties or elements in a collection. The following example shows what that looks like in practice.

```swift
struct Nested: Encodable {
    let tag: String
    let flag: Bool
    let nested: [Nested]
}
let boundary = "abc123"
let nested = Nested(tag: "a", flag: true, nested: [Nested(tag: "b", flag: false, nested: [])])
let encoded = try FormDataEncoder().encode(nested, boundary: boundary)
```

This results in the content below.

```
--abc123
Content-Disposition: form-data; name="tag"

a
--abc123
Content-Disposition: form-data; name="flag"

true
--abc123
Content-Disposition: form-data; name="nested[0][tag]"

b
--abc123
Content-Disposition: form-data; name="nested[0][flag]"

false
--abc123--
```

Note that the array elements always include the index (as opposed to just `[]`) in order to support complex nesting.

## Working with parts directly

If you don't need `Codable`, you can work with `MultipartPart` values yourself. Each part exposes its `headerFields` and `body`, and can parse its own `Content-Disposition` header.

```swift
let parts = try MultipartParser<ArraySlice<UInt8>>(boundary: boundary).parse(message)

for part in parts {
    // ...
}
```

`ContentDisposition` gives you the parsed `dispositionType`, `name`, `filename`, and any `additionalParameters`, rather than making you pick the header apart by hand.

## Streaming

`MultipartParser.parse(_:)` needs the whole message up front. To parse a message as it arrives, wrap any `AsyncSequence` of body chunks in one of the two parser sequences.

`StreamingMultipartParserAsyncSequence` yields each body chunk as soon as it is parsed, so a large file never has to be held in memory in full.
``MultipartParserAsyncSequence`` behaves the same way, but collates each part's body chunks into a single ``MultipartSection/bodyChunk(_:)`` section, which is friendlier when parts are small enough to hold in memory.

```swift
let sequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: stream)

for try await section in sequence {
    switch section {
    case .headerFields(let fields):
        print(fields[.contentDisposition] ?? "")
    case .bodyChunk(let chunk):
        try await file.write(contentsOf: chunk)
    case .boundary(let end):
        print(end ? "message finished" : "part finished")
    }
}
```

## Serializing

Serialization goes through the `MultipartWriter` protocol. `MemoryMultipartWriter` collects the message in memory and hands it back to you.

```swift
var writer = MemoryMultipartWriter<[UInt8]>(boundary: boundary)

try await writer.writePart(
    MultipartPart(
        headerFields: [.contentDisposition: #"form-data; name="file"; filename="hello.txt""#],
        body: Array("Hello, world!".utf8)
    )
)
try await writer.finish()

let serialized = writer.getResult()
```

To write somewhere other than memory, conform your own type to `MultipartWriter`. Implementing `write(bytes:)` is enough: boundaries, headers, and parts all get default implementations on top of it.

Finally, `StreamingMultipartWriterAsyncSequence` turns an `AsyncSequence` of `MultipartSection`s into an `AsyncSequence` of serialized chunks, which is the mirror image of the streaming parser.

```swift
let sequence = StreamingMultipartWriterAsyncSequence(
    backingSequence: sections,
    boundary: boundary,
    outboundBody: ArraySlice<UInt8>.self
)

for try await chunk in sequence {
    try await socket.write(chunk)
}
```
