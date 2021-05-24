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

// The parts of RangeReplaceableCollection that OrderedDictionary is able to implement.

extension OrderedDictionary {
  /// Reserves enough space to store the specified number of elements.
  ///
  /// This method ensures that the dictionary has unique, mutable, contiguous
  /// storage, with space allocated for at least the requested number of
  /// elements.
  ///
  /// If you are adding a known number of elements to a dictionary, call this
  /// method once before the first insertion to avoid multiple reallocations.
  ///
  /// Do not call this method in a loop -- it does not use an exponential
  /// allocation strategy, so doing that can result in quadratic instead of
  /// linear performance.
  ///
  /// - Parameter minimumCapacity: The minimum number of elements that the
  ///   dictionary should be able to store without reallocating its storage.
  ///
  /// - Complexity: O(`max(count, minimumCapacity)`)
  @inlinable
  internal mutating func reserveCapacity(_ minimumCapacity: Int) {
    self._keys.reserveCapacity(minimumCapacity)
    self._values.reserveCapacity(minimumCapacity)
  }
}
