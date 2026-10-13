import HTTPTypes

/// Holds either the actual body bytes, or the ``MultipartPartEncodable`` object.
/// Using the latter allows us to transport it between the ``FormaDataEncoder`` and
/// ``MultipartWriter`` without materialising it into bytes twice when encoding data.
struct DeferrableBodyPart<Body: MultipartPartBodyElement> {
    enum StoredBody {
        case owned(Body)
        case deferred(any MultipartPartEncodable)

        var count: Int {
            switch self {
            case .owned(let body): body.count
            case .deferred(let codable): codable.withBody { $0.byteCount }
            }
        }
    }

    var headerFields: HTTPFields
    let body: StoredBody
}
