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

extension OrderedSet {
  /// Append a new member to the end of the set, without verifying
  /// that the set doesn't already contain it.
  ///
  /// This operation performs no hashing operations unless it needs to
  /// reallocate the hash table.
  ///
  /// - Complexity: Expected to be O(1) on average if `Element`
  ///    implements high-quality hashing.
  @inlinable
  internal mutating func _appendNew(_ item: Element) {
    assert(!contains(item))
    _elements.append(item)
    guard _elements.count <= _capacity else {
      _regenerateHashTable()
      return
    }
    guard _table != nil else { return }
    _ensureUnique()
    _table!.update { hashTable in
      var it = hashTable.bucketIterator(for: item)
      it.advanceToNextUnoccupiedBucket()
      it.currentValue = _elements.count - 1
    }
  }

  /// Append a new member to the end of the set, registering it in the
  /// specified hash table bucket, without verifying that the set
  /// doesn't already contain it.
  ///
  /// This operation performs no hashing operations unless it needs to
  /// reallocate the hash table.
  ///
  /// - Complexity: Amortized O(1)
  @inlinable
  internal mutating func _appendNew(_ item: Element, in bucket: _Bucket) {
    _elements.append(item)

    guard _elements.count <= _capacity else {
      _regenerateHashTable()
      return
    }
    guard _table != nil else { return }
    _ensureUnique()
    _table!.update { hashTable in
      assert(!hashTable.isOccupied(bucket))
      hashTable[bucket] = _elements.count - 1
    }
  }

  @inlinable
  @discardableResult
  internal mutating func _append(_ item: Element) -> (inserted: Bool, index: Int) {
    let (index, bucket) = _find(item)
    if let index = index { return (false, index) }
    _appendNew(item, in: bucket)
    return (true, _elements.index(before: _elements.endIndex))
  }

  /// Append a new member to the end of the set, if the set doesn't
  /// already contain it.
  ///
  /// - Parameter item: The element to add to the set.
  ///
  /// - Returns: A pair `(inserted, index)`, where `inserted` is a Boolean value
  ///    indicating whether the operation added a new element, and `index` is
  ///    the index of `item` in the resulting set.
  ///
  /// - Complexity: The operation is expected to perform O(1) copy, hash, and
  ///    compare operations on the `Element` type, if it implements high-quality
  ///    hashing.
  @inlinable
  @inline(__always)
  @discardableResult
  internal mutating func append(_ item: Element) -> (inserted: Bool, index: Int) {
    let result = _append(item)
    _checkInvariants()
    return result
  }
}
