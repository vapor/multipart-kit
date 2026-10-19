import HTTPTypes
import OrderedCollections

final class Storage<Body: MultipartPartBodyElement> {
    var dataContainer: (any DataContainer<Body>)?

    var data: MultipartFormData<DeferrableBodyPart<Body>>? {
        dataContainer?.data
    }
}

protocol DataContainer<Body> {
    associatedtype Body: MultipartPartBodyElement
    var data: MultipartFormData<DeferrableBodyPart<Body>> { get }
}

struct SingleValueDataContainer<Body: MultipartPartBodyElement>: DataContainer {
    let data: MultipartFormData<DeferrableBodyPart<Body>>

    init(part: MultipartPart<Body>) {
        self.data = .single(.init(headerFields: part.headerFields, body: .owned(part.body)))
    }

    init(headerFields: HTTPFields, body: some MultipartPartEncodable) {
        self.data = .single(.init(headerFields: headerFields, body: .deferred(body)))
    }
}

final class KeyedDataContainer<Body: MultipartPartBodyElement>: DataContainer {
    var value: OrderedDictionary<String, Storage<Body>> = [:]

    var data: MultipartFormData<DeferrableBodyPart<Body>> {
        .keyed(value.compactMapValues(\.data))
    }
}

final class UnkeyedDataContainer<Body: MultipartPartBodyElement>: DataContainer {
    var value: [Storage<Body>] = []

    var data: MultipartFormData<DeferrableBodyPart<Body>> {
        .array(value.compactMap(\.data))
    }
}
