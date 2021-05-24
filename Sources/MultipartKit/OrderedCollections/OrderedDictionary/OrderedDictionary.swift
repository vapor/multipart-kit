//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

/// An ordered collection of key-value pairs.
///
/// Like the standard `Dictionary`, ordered dictionaries use a hash table to
/// ensure that no two entries have the same keys, and to efficiently look up
/// values corresponding to specific keys. However, like an `Array` (and
/// unlike `Dictionary`), ordered dictionaries maintain their elements in a
/// particular user-specified order, and they support efficient random-access
/// traversal of their entries.
///
/// `OrderedDictionary` is a useful alternative to `Dictionary` when the order
/// of elements is important, or when you need to be able to efficiently access
/// elements at various positions within the collection.
///
/// You can create an ordered dictionary with any key type that conforms to the
/// `Hashable` protocol.
///
///     let responses: OrderedDictionary = [
///       200: "OK",
///       403: "Access forbidden",
///       404: "File not found",
///       500: "Internal server error",
///     ]
///
/// ### Equality of Ordered Dictionaries
///
/// Two ordered dictionaries are considered equal if they contain the same
/// elements, and *in the same order*. This matches the concept of equality of
/// an `Array`, and it is different from the unordered `Dictionary`.
///
///     let a: OrderedDictionary = [1: "one", 2: "two"]
///     let b: OrderedDictionary = [2: "two", 1: "one"]
///     a == b // false
///     b.swapAt(0, 1) // `b` now has value [1: "one", 2: "two"]
///     a == b // true
///
/// (`OrderedDictionary` only conforms to `Equatable` when its `Value` is
/// equatable.)
///
/// ### Dictionary Operations
///
/// `OrderedDictionary` provides many of the same operations as `Dictionary`.
///
/// For example, you can look up and add/remove values using the familiar
/// key-based subscript, returning an optional value:
///
///     var dictionary: OrderedDictionary<String, Int> = [:]
///     dictionary["one"] = 1
///     dictionary["two"] = 2
///     dictionary["three"] // nil
///     // dictionary is now ["one": 1, "two": 2]
///
/// If a new entry is added using the subscript setter, it gets appended to the
/// end of the dictionary. (So that by default, the dictionary contains its
/// elements in the order they were originally inserted.)
///
/// `OrderedDictionary` also implements the variant of this subscript that takes
/// a default value. Like with `Dictionary`, this is useful when you want to
/// perform in-place mutations on values:
///
///     let text = "short string"
///     var counts: OrderedDictionary<Character, Int> = [:]
///     for character in text {
///       counts[character, default: 0] += 1
///     }
///     // counts is ["s": 2, "h": 1, "o": 1,
///     //            "r": 2, "t": 2, " ": 1,
///     //            "i": 1, "n": 1, "g": 1]
///
/// If the `Value` type implements reference semantics, or when you need to
/// perform a series of individual mutations on the values, the closure-based
/// `modifyValue(forKey:default:_:)` method provides an easier-to-use
/// alternative to the defaulted key-based subscript.
///
///     let text = "short string"
///     var counts: OrderedDictionary<Character, Int> = [:]
///     for character in text {
///       counts.modifyValue(forKey: character, default: 0) { value in
///         value += 1
///       }
///     }
///     // Same result as before
///
/// (This isn't currently available on the regular `Dictionary`.)
///
/// The `Dictionary` type's original `updateValue(_:forKey:)` method is also
/// available, and so is `index(forKey:)`, grouping/uniquing initializers
/// (`init(uniqueKeysWithValues:)`, `init(_:uniquingKeysWith:)`,
/// `init(grouping:by:)`), methods for merging one dictionary with another
/// (`merge`, `merging`), filtering dictionary entries (`filter(_:)`),
/// transforming values (`mapValues(_:)`), and a combination of these two
/// (`compactMapValues(_:)`).
///
/// ### Sequence and Collection Operations
///
/// Ordered dictionaries use integer indices representing offsets from the
/// beginning of the collection. However, to avoid ambiguity between key-based
/// and indexing subscripts, `OrderedDictionary` doesn't directly conform to
/// `Collection`. Instead, it only conforms to `Sequence`, and provides a
/// random-access collection view over its key-value pairs:
///
///     responses[0] // `nil` (key-based subscript)
///     responses.elements[0] // `(200, "OK")` (index-based subscript)
///
/// Because ordered dictionaries need to maintain unique keys, neither
/// `OrderedDictionary` nor its `elements` view can conform to the full
/// `MutableCollection` or `RangeReplaceableCollection` protocols. However, they
/// are able to partially implement requirements: they support mutations
/// that merely change the order of elements, or just remove a subset of
/// existing members:
///
///     // Permutation operations from MutableCollection:
///     func swapAt(_ i: Int, _ j: Int)
///     func partition(by predicate: (Element) throws -> Bool) -> rethrows Int
///     func sort() where Element: Comparable
///     func sort(by predicate: (Element, Element) throws -> Bool) rethrows
///     func shuffle()
///     func shuffle<T: RandomNumberGenerator>(using generator: inout T)
///
///     // Removal operations from RangeReplaceableCollection:
///     func removeAll(keepingCapacity: Bool = false)
///     func remove(at index: Int) -> Element
///     func removeSubrange(_ bounds: Range<Int>)
///     func removeLast() -> Element
///     func removeLast(_ n: Int)
///     func removeFirst() -> Element
///     func removeFirst(_ n: Int)
///     func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows
///
/// `OrderedDictionary` also implements `reserveCapacity(_)` from
/// `RangeReplaceableCollection`, to allow for efficient insertion of a known
/// number of elements. (However, unlike `Array` and `Dictionary`,
/// `OrderedDictionary` does not provide a `capacity` property.)
///
/// ### Keys and Values Views
///
/// Like the standard `Dictionary`, `OrderedDictionary` provides `keys` and
/// `values` properties that provide lightweight views into the corresponding
/// parts of the dictionary.
///
/// The `keys` collection is of type `OrderedSet<Key>`, containing all the keys
/// in the original dictionary.
///
///     let d: OrderedDictionary = [2: "two", 1: "one", 0: "zero"]
///     d.keys // [2, 1, 0] as OrderedSet<Int>
///
/// The `keys` property is read-only, so you cannot mutate the dictionary
/// through it. However, it returns an ordinary ordered set value, which can be
/// copied out and then mutated if desired. (Such mutations won't affect the
/// original dictionary value.)
///
/// The `values` collection is a mutable random-access collection of the values
/// in the dictionary:
///
///     d.values // "two", "one", "zero"
///     d.values[2] = "nada"
///     // `d` is now [2: "two", 1: "one", 0: "nada"]
///     d.values.sort()
///     // `d` is now [2: "nada", 1: "one", 0: "two"]
///
/// Both views store their contents in regular `Array` values, accessible
/// through their `elements` property.
///
/// ## Performance
///
/// Like the standard `Dictionary` type, the performance of hashing operations
/// in `OrderedDictionary` is highly sensitive to the quality of hashing
/// implemented by the `Key` type. Failing to correctly implement hashing can
/// easily lead to unacceptable performance, with the severity of the effect
/// increasing with the size of the hash table.
///
/// In particular, if a certain set of keys all produce the same hash value,
/// then hash table lookups regress to searching an element in an unsorted
/// array, i.e., a linear operation. To ensure hashed collection types exhibit
/// their target performance, it is important to ensure that such collisions
/// cannot be induced merely by adding a particular list of keys to the
/// dictionary.
///
/// The easiest way to achieve this is to make sure `Key` implements hashing
/// following `Hashable`'s documented best practices. The conformance must
/// implement the `hash(into:)` requirement, and every bit of information that
/// is compared in `==` needs to be combined into the supplied `Hasher` value.
/// When used correctly, `Hasher` produces high-quality, randomly seeded hash
/// values that prevent repeatable hash collisions.
///
/// When `Key` correctly conforms to `Hashable`, key-based lookups in an ordered
/// dictionary is expected to take O(1) equality checks on average. Hash
/// collisions can still occur organically, so the worst-case lookup performance
/// is technically still O(*n*) (where *n* is the size of the dictionary);
/// however, long lookup chains are unlikely to occur in practice.
///
/// ## Implementation Details
///
/// An ordered dictionary consists of an ordered set of keys, alongside a
/// regular `Array` value that contains their associated values.
@frozen
public struct OrderedDictionary<Key: Hashable, Value> {
  @usableFromInline
  internal var _keys: OrderedSet<Key>

  @usableFromInline
  internal var _values: ContiguousArray<Value>

  @inlinable
  @inline(__always)
  internal init(
    _uniqueKeys keys: OrderedSet<Key>,
    values: ContiguousArray<Value>
  ) {
    self._keys = keys
    self._values = values
  }
}

extension OrderedDictionary {
  /// A read-only collection view for the keys contained in this dictionary, as
  /// an `OrderedSet`.
  ///
  /// - Complexity: O(1)
  @inlinable
  @inline(__always)
  public var keys: OrderedSet<Key> { _keys }
}

extension OrderedDictionary {
  /// The number of elements in the dictionary.
  ///
  /// - Complexity: O(1)
  @inlinable
  @inline(__always)
  public var count: Int { _values.count }
}

extension OrderedDictionary {
  /// Accesses the value associated with the given key for reading and writing.
  ///
  /// This *key-based* subscript returns the value for the given key if the key
  /// is found in the dictionary, or `nil` if the key is not found.
  ///
  /// The following example creates a new dictionary and prints the value of a
  /// key found in the dictionary (`"Coral"`) and a key not found in the
  /// dictionary (`"Cerise"`).
  ///
  ///     var hues: OrderedDictionary = ["Heliotrope": 296, "Coral": 16, "Aquamarine": 156]
  ///     print(hues["Coral"])
  ///     // Prints "Optional(16)"
  ///     print(hues["Cerise"])
  ///     // Prints "nil"
  ///
  /// When you assign a value for a key and that key already exists, the
  /// dictionary overwrites the existing value. If the dictionary doesn't
  /// contain the key, the key and value are added as a new key-value pair.
  ///
  /// Here, the value for the key `"Coral"` is updated from `16` to `18` and a
  /// new key-value pair is added for the key `"Cerise"`.
  ///
  ///     hues["Coral"] = 18
  ///     print(hues["Coral"])
  ///     // Prints "Optional(18)"
  ///
  ///     hues["Cerise"] = 330
  ///     print(hues["Cerise"])
  ///     // Prints "Optional(330)"
  ///
  /// If you assign `nil` as the value for the given key, the dictionary
  /// removes that key and its associated value.
  ///
  /// In the following example, the key-value pair for the key `"Aquamarine"`
  /// is removed from the dictionary by assigning `nil` to the key-based
  /// subscript.
  ///
  ///     hues["Aquamarine"] = nil
  ///     print(hues)
  ///     // Prints "["Coral": 18, "Heliotrope": 296, "Cerise": 330]"
  ///
  /// - Parameter key: The key to find in the dictionary.
  ///
  /// - Returns: The value associated with `key` if `key` is in the dictionary;
  ///   otherwise, `nil`.
  ///
  /// - Complexity: Looking up values in the dictionary through this subscript
  ///    has an expected complexity of O(1) hashing/comparison operations on
  ///    average, if `Key` implements high-quality hashing. Updating the
  ///    dictionary also has an amortized expected complexity of O(1) --
  ///    although individual updates may need to copy or resize the dictionary's
  ///    underlying storage.
  @inlinable
  public subscript(key: Key) -> Value? {
    get {
      guard let index = _keys.firstIndex(of: key) else { return nil }
      return _values[index]
    }
    set {
      // We have a separate `set` in addition to `_modify` in hopes of getting
      // rid of `_modify`'s swapAt dance in the usua case where the calle just
      // wants to assign a new value.
      let (index, bucket) = _keys._find(key)
      switch (index, newValue) {
      case let (index?, newValue?): // Assign
        _values[index] = newValue
      case let (index?, nil): // Remove
        _keys._removeExistingMember(at: index, in: bucket)
        _values.remove(at: index)
      case let (nil, newValue?): // Insert
        _keys._appendNew(key, in: bucket)
        _values.append(newValue)
      case (nil, nil): // Noop
        break
      }
    }
    _modify {
      let (index, bucket) = _keys._find(key)

      // To support in-place mutations better, we swap the value to the end of
      // the array, pop it off, then put things back in place when we're done.
      var value: Value? = nil
      if let index = index {
        _values.swapAt(index, _values.count - 1)
        value = _values.removeLast()
      }

      defer {
        switch (index, value) {
        case let (index?, value?): // Assign
          _values.append(value)
          _values.swapAt(index, _values.count - 1)
        case let (index?, nil): // Remove
          if index < _values.count {
            let standin = _values.remove(at: index)
            _values.append(standin)
          }
          _keys._removeExistingMember(at: index, in: bucket)
        case let (nil, value?): // Insert
          _keys._appendNew(key, in: bucket)
          _values.append(value)
        case (nil, nil): // Noop
          break
        }
      }

      yield &value
    }
  }

  /// Accesses the value with the given key. If the dictionary doesn't contain
  /// the given key, accesses the provided default value as if the key and
  /// default value existed in the dictionary.
  ///
  /// Use this subscript when you want either the value for a particular key
  /// or, when that key is not present in the dictionary, a default value. This
  /// example uses the subscript with a message to use in case an HTTP response
  /// code isn't recognized:
  ///
  ///     var responseMessages: OrderedDictionary = [
  ///         200: "OK",
  ///         403: "Access forbidden",
  ///         404: "File not found",
  ///         500: "Internal server error"]
  ///
  ///     let httpResponseCodes = [200, 403, 301]
  ///     for code in httpResponseCodes {
  ///         let message = responseMessages[code, default: "Unknown response"]
  ///         print("Response \(code): \(message)")
  ///     }
  ///     // Prints "Response 200: OK"
  ///     // Prints "Response 403: Access forbidden"
  ///     // Prints "Response 301: Unknown response"
  ///
  /// When a dictionary's `Value` type has value semantics, you can use this
  /// subscript to perform in-place operations on values in the dictionary.
  /// The following example uses this subscript while counting the occurrences
  /// of each letter in a string:
  ///
  ///     let message = "Hello, Elle!"
  ///     var letterCounts: [Character: Int] = [:]
  ///     for letter in message {
  ///         letterCounts[letter, default: 0] += 1
  ///     }
  ///     // letterCounts == ["H": 1, "e": 2, "l": 4, "o": 1, ...]
  ///
  /// When `letterCounts[letter, defaultValue: 0] += 1` is executed with a
  /// value of `letter` that isn't already a key in `letterCounts`, the
  /// specified default value (`0`) is returned from the subscript,
  /// incremented, and then added to the dictionary under that key.
  ///
  /// - Note: Do not use this subscript to modify dictionary values if the
  ///   dictionary's `Value` type is a class. In that case, the default value
  ///   and key are not written back to the dictionary after an operation. (For
  ///   a variant of this operation that supports this usecase, see
  ///   `updateValue(forKey:default:_:)`.)
  ///
  /// - Parameters:
  ///   - key: The key the look up in the dictionary.
  ///   - defaultValue: The default value to use if `key` doesn't exist in the
  ///     dictionary.
  ///
  /// - Returns: The value associated with `key` in the dictionary; otherwise,
  ///   `defaultValue`.
  ///
  /// - Complexity: Looking up values in the dictionary through this subscript
  ///    has an expected complexity of O(1) hashing/comparison operations on
  ///    average, if `Key` implements high-quality hashing. Updating the
  ///    dictionary also has an amortized expected complexity of O(1) --
  ///    although individual updates may need to copy or resize the dictionary's
  ///    underlying storage.
  @inlinable
  public subscript(
    key: Key,
    default defaultValue: @autoclosure () -> Value
  ) -> Value {
    get {
      guard let offset = _keys.firstIndex(of: key) else { return defaultValue() }
      return _values[offset]
    }
    _modify {
      let (inserted, index) = _keys.append(key)
      if inserted {
        assert(index == _values.count)
        _values.append(defaultValue())
      }
      var value: Value = _values.withUnsafeMutableBufferPointer { buffer in
        assert(index < buffer.count)
        return (buffer.baseAddress! + index).move()
      }
      defer {
        _values.withUnsafeMutableBufferPointer { buffer in
          assert(index < buffer.count)
          (buffer.baseAddress! + index).initialize(to: value)
        }
      }
      yield &value
    }
  }
}

extension OrderedDictionary {
  /// Returns a new dictionary containing the keys of this dictionary with the
  /// values transformed by the given closure.
  ///
  /// - Parameter transform: A closure that transforms a value. `transform`
  ///   accepts each value of the dictionary as its parameter and returns a
  ///   transformed value of the same or of a different type.
  /// - Returns: A dictionary containing the keys and transformed values of
  ///   this dictionary.
  ///
  /// - Complexity: O(`count`)
  @inlinable
  public func mapValues<T>(
    _ transform: (Value) throws -> T
  ) rethrows -> OrderedDictionary<Key, T> {
    OrderedDictionary<Key, T>(
      _uniqueKeys: _keys,
      values: ContiguousArray(try _values.map(transform)))
  }
}
