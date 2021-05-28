/* Changes for MultipartKit
    - removed all functionality not needed by MultipartKit
    - made all public APIs internal

   DO NOT CHANGE THESE FILES, THEY ARE VENDORED FROM Swift Collections.
*/
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

extension OrderedDictionary {
  /// Creates an empty dictionary.
  ///
  /// This initializer is equivalent to initializing with an empty dictionary
  /// literal.
  ///
  /// - Complexity: O(1)
  @inlinable
  @inline(__always)
  internal init() {
    self._keys = OrderedSet()
    self._values = []
  }
}

extension OrderedDictionary {
  /// Creates a new dictionary from the key-value pairs in the given sequence.
  ///
  /// You use this initializer to create a dictionary when you have a sequence
  /// of key-value tuples with unique keys. Passing a sequence with duplicate
  /// keys to this initializer results in a runtime error. If your
  /// sequence might have duplicate keys, use the
  /// `Dictionary(_:uniquingKeysWith:)` initializer instead.
  ///
  /// - Parameter keysAndValues: A sequence of key-value pairs to use for
  ///   the new dictionary. Every key in `keysAndValues` must be unique.
  ///
  /// - Returns: A new dictionary initialized with the elements of
  ///   `keysAndValues`.
  ///
  /// - Precondition: The sequence must not have duplicate keys.
  ///
  /// - Complexity: Expected O(*n*) on average, where *n* is the count if
  ///    key-value pairs, if `Key` implements high-quality hashing.
  @inlinable
  internal init<S: Sequence>(
    uniqueKeysWithValues keysAndValues: S
  ) where S.Element == (key: Key, value: Value) {
    if S.self == Dictionary<Key, Value>.self {
      self.init(_uncheckedUniqueKeysWithValues: keysAndValues)
      return
    }
    self.init()
    reserveCapacity(keysAndValues.underestimatedCount)
    for (key, value) in keysAndValues {
      guard _keys._append(key).inserted else {
        preconditionFailure("Duplicate key: '\(key)'")
      }
      _values.append(value)
    }
  }

  /// Creates a new dictionary from the key-value pairs in the given sequence.
  ///
  /// You use this initializer to create a dictionary when you have a sequence
  /// of key-value tuples with unique keys. Passing a sequence with duplicate
  /// keys to this initializer results in a runtime error. If your
  /// sequence might have duplicate keys, use the
  /// `Dictionary(_:uniquingKeysWith:)` initializer instead.
  ///
  /// - Parameter keysAndValues: A sequence of key-value pairs to use for
  ///   the new dictionary. Every key in `keysAndValues` must be unique.
  ///
  /// - Returns: A new dictionary initialized with the elements of
  ///   `keysAndValues`.
  ///
  /// - Precondition: The sequence must not have duplicate keys.
  ///
  /// - Complexity: Expected O(*n*) on average, where *n* is the count if
  ///    key-value pairs, if `Key` implements high-quality hashing.
  @inlinable
  internal init<S: Sequence>(
    uniqueKeysWithValues keysAndValues: S
  ) where S.Element == (Key, Value) {
    self.init()
    reserveCapacity(keysAndValues.underestimatedCount)
    for (key, value) in keysAndValues {
      guard _keys._append(key).inserted else {
        preconditionFailure("Duplicate key: '\(key)'")
      }
      _values.append(value)
    }
  }
}

extension OrderedDictionary {
  @inlinable
  internal init<S: Sequence>(
    _uncheckedUniqueKeysWithValues keysAndValues: S
  ) where S.Element == (key: Key, value: Value) {
    self.init()
    reserveCapacity(keysAndValues.underestimatedCount)
    for (key, value) in keysAndValues {
      _keys._appendNew(key)
      _values.append(value)
    }
  }
}
