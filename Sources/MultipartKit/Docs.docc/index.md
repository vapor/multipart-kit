# ``MultipartKit``

Parser, serializer, and `Codable` support for `multipart/form-data`.

## Overview

MultipartKit is a Swift package for parsing and serializing `multipart/form-data` requests. It provides `Codable` support for handling `multipart/form-data` data through a ``FormDataEncoder`` and ``FormDataDecoder``. Parsing and serialization are also exposed as `AsyncSequence`s, so large messages can be streamed without ever being held in memory in full.

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

We can encode this instance of our type using a ``FormDataEncoder``.

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

In order to _decode_ this message we feed this output and the same boundary to a ``FormDataDecoder`` and we get back an identical instance to the one we started with.

```swift
let decoded = try FormDataDecoder().decode(User.self, from: encoded, boundary: boundary)
```

`encode` returns a `String` above, but it can produce any ``MultipartPartBodyElement``, or append into a buffer you already own.

```swift
// Encode into a body type of your choosing.
let bytes: [UInt8] = try FormDataEncoder().encode(user, boundary: boundary)

// Or append into an existing buffer.
var buffer: [UInt8] = []
try FormDataEncoder().encode(user, boundary: boundary, into: &buffer)
```

Likewise, ``FormDataDecoder`` decodes from a `String` or from any ``MultipartPartBodyElement``.

### A note on `null`

As there is no standard defined for how to represent `null` in Multipart (unlike, for instance, JSON), ``FormDataEncoder`` and ``FormDataDecoder`` do not support encoding or decoding `null` respectively.

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

### Working with parts directly

If you don't need `Codable`, you can work with ``MultipartPart`` values yourself. Each part exposes its header fields and body, and can parse its own `Content-Disposition` header into a ``ContentDisposition``.

```swift
let parts = try MultipartParser<ArraySlice<UInt8>>(boundary: boundary).parse(message)

for part in parts {
    // ...
}
```

### Streaming

``MultipartParser/parse(_:)`` needs the whole message up front. To parse a message as it arrives, wrap any `AsyncSequence` of body chunks in one of the two parser sequences.

``StreamingMultipartParserAsyncSequence`` yields each body chunk as soon as it is parsed, so a large file never has to be held in memory in full. ``MultipartParserAsyncSequence`` behaves the same way, but collates each part's body chunks into a single ``MultipartSection/bodyChunk(_:)`` section, which is friendlier when parts are small enough to hold in memory.

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
