import Collections

final class Storage<Body: MultipartPartBodyElement> {
    var dataContainer: (any DataContainer)? = nil
    var data: MultipartFormData<Body>? {
        dataContainer?.data
    }
}

protocol DataContainer<Body> {
    associatedtype Body: MultipartPartBodyElement
    var data: MultipartFormData<Body> { get }
}

struct SingleValueDataContainer<Body: MultipartPartBodyElement>: DataContainer {
    init(part: MultipartPart<Body>) {
        data = .single(part)
    }
    let data: MultipartFormData<Body>
}

final class KeyedDataContainer<Body: MultipartPartBodyElement>: DataContainer {
    var value: OrderedDictionary<String, Storage> = [:]
    var data: MultipartFormData<Body> {
        .keyed(value.compactMapValues(\.data))
    }
}

final class UnkeyedDataContainer: DataContainer {
    var value: [Storage] = []
    var data: MultipartFormData {
        .array(value.compactMap(\.data))
    }
}
