import Fuzzing
import MultipartKit

/// Shaped to reach as much of the decoder as one type can: a keyed container, a
/// nested keyed container, an unkeyed container, and single-value decoding of
/// several primitives.
private struct Probe: Decodable {
    struct Nested: Decodable {
        let text: String?
        let flag: Bool?
    }
    let name: String?
    let count: Int?
    let ratio: Double?
    let items: [String]?
    let nested: Nested?
    let data: [UInt8]?
}

let fuzzTargets: @Sendable () -> Void = {
    // `FormDataDecoder` is a separate entry point from `MultipartParser.parse`:
    // it parses, builds a `MultipartFormData` tree, and then runs `Decodable`
    // over it. The tree-building step is where the nesting limit lives, and
    // neither it nor the containers underneath were reached by any other target.
    FuzzTarget.structured("FormDataDecode") { data in
        var data = data
        let boundary = data.element(of: ["boundary123", "", "-", "--"]) ?? "boundary123"
        // The configured limit is drawn too. It bounds how deep a bracketed
        // field name may nest, and the interesting question is whether a name
        // can outrun whatever it is set to.
        let nestingDepth = Int(data.integer(in: UInt8(1)...UInt8(32)))
        let body = data.remainingBytes()

        _ = try? FormDataDecoder(nestingDepth: nestingDepth)
            .decode(Probe.self, from: body, boundary: boundary)
    }
}
