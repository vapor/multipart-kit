import Fuzzing
import MultipartKit

/// Shaped to drive the encoder through keyed, nested-keyed and unkeyed
/// containers, and single-value encoding of several primitives.
private struct Probe: Codable, Equatable {
    struct Nested: Codable, Equatable {
        var text: String
        var flag: Bool
    }
    var name: String
    var count: Int
    var ratio: Double
    var items: [String]
    var nested: Nested
}

let fuzzTargets: @Sendable () -> Void = {
    // The encode half of the Codable path. `FormDataEncoder` and its containers
    // were untouched by every other target — `FormDataDecode` only ever runs the
    // decoder.
    //
    // The oracle is the pair being inverse: a value encoded and decoded must
    // come back equal. That is what makes this worth more than crash-freedom,
    // because an encoder and a decoder in the same package disagreeing about
    // their own wire format is exactly the bug neither one's tests would catch.
    FuzzTarget.structured("FormDataRoundTrip") { data in
        var data = data

        let probe = Probe(
            // Text is drawn as chunks rather than free bytes so it stays valid
            // UTF-8 through the encoder; invalid UTF-8 in a header value is
            // `MultipartParse`'s territory.
            name: data.text(),
            count: Int(data.integer(Int32.self)),
            ratio: Double(data.integer(Int32.self)),
            items: (0..<Int(data.integer(in: UInt8(0)...UInt8(4)))).map { _ in data.text() },
            nested: .init(text: data.text(), flag: data.bool())
        )

        let boundary = "boundary123"
        guard let encoded: [UInt8] = try? FormDataEncoder().encode(probe, boundary: boundary) else {
            return
        }
        // Known finding: an empty array encodes to nothing at all — no part is
        // written for it — so the decoder has nothing to rebuild `[String]`
        // from and throws. Empty *strings* survive fine; it is specific to
        // collections. Still encoded and decoded here, because that path is
        // worth executing; just not re-asserted. Remove this guard when the
        // encoder gains a representation for an empty collection.
        let hasEmptyCollection = probe.items.isEmpty

        guard let decoded = try? FormDataDecoder().decode(Probe.self, from: encoded, boundary: boundary)
        else {
            if hasEmptyCollection { return }
            fatalError("""
                a value this library encoded does not decode back
                  probe: \(probe)
                  encoded: \(String(decoding: encoded, as: UTF8.self).debugDescription)
                """)
        }
        guard decoded == probe else {
            fatalError("""
                encode/decode is not a fixed point
                  in:  \(probe)
                  out: \(decoded)
                """)
        }
    }
}
