import Collections
import Synchronization

final class Storage<Body: MultipartPartBodyElement>: Sendable {
    private let _dataContainer: (any DataContainer<Body>)? = nil
    private let box: Mutex<(any DataContainer<Body>)?> = .init(nil)

    var dataContainer: (any DataContainer<Body>)? {
        get { box.withLock { $0 } }
        set { box.withLock { $0 = newValue } }
    }

    var data: MultipartFormData<Body>? {
        dataContainer?.data
    }
}

protocol DataContainer<Body>: Sendable {
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
    private let _value: OrderedDictionary<String, Storage<Body>> = [:]
    private let box: Mutex<OrderedDictionary<String, Storage<Body>>> = .init(.init())

    var value: OrderedDictionary<String, Storage<Body>> {
        get { box.withLock { $0 } }
        set { box.withLock { $0 = newValue } }
    }

    var data: MultipartFormData<Body> {
        .keyed(value.compactMapValues(\.data))
    }
}

final class UnkeyedDataContainer<Body: MultipartPartBodyElement>: DataContainer {
    private let _value: [Storage<Body>] = []
    private let box: Mutex<[Storage<Body>]> = .init(.init())

    var value: [Storage<Body>] {
        get { box.withLock { $0 } }
        set { box.withLock { $0 = newValue } }
    }

    var data: MultipartFormData<Body> {
        .array(value.compactMap(\.data))
    }
}
