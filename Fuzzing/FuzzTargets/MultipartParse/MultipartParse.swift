import Fuzzing
import MultipartKit

let fuzzTargets: @Sendable () -> Void = {
    // The whole-message parser. Both halves of its input come off the wire: the
    // body is the request body, and the boundary is a parameter of the
    // Content-Type header, so a server has no more say over one than the other.
    //
    // The boundary is drawn first and bounded, which leaves the body as
    // everything after it — the body is the interesting half, and a seed is
    // then a boundary followed by a message.
    FuzzTarget.structured("MultipartParse") { data in
        var data = data
        // Drawn from a set rather than fuzzed freely, for two reasons. A boundary
        // that never matches anything in the body means the parser is only ever
        // exercised on its "found nothing" path. And holding the draw to a fixed
        // 8 bytes off the back leaves the whole front of the input as the body,
        // so a seed is a real multipart message on disk rather than something
        // reverse-engineered out of the provider's draw order.
        //
        // The illegal ones are in the set on purpose: RFC 2046 constrains what a
        // boundary may contain, and the question is what this parser does when a
        // client ignores that.
        let boundary = data.element(of: [
            "boundary123",
            "",                       // empty
            "-",                      // collides with the leading dashes
            "--",
            "\r\n",                   // a boundary that is itself a line break
            String(repeating: "a", count: 200),
        ]) ?? "boundary123"
        let body = data.remainingBytes()

        let parser = MultipartParser<[UInt8]>(boundary: boundary)
        guard let parts = try? parser.parse(body) else { return }

        // Touch what a caller reads. Parsing that succeeds and then hands back
        // a part whose accessors trap is the same bug from the caller's side.
        for part in parts {
            _ = part.body
            for field in part.headerFields { _ = field.value }
            // `contentDisposition` is computed, and parses the header on each
            // access — so reading it puts the Content-Disposition parser under
            // test too, without a target of its own.
            if let disposition = try? part.contentDisposition {
                _ = disposition.name
                _ = disposition.filename
                _ = disposition.dispositionType
                _ = disposition.additionalParameters
            }
        }
    }
}
