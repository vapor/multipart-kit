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

extension OrderedSet: Equatable {
  /// Returns a Boolean value indicating whether two values are equal.
  ///
  /// Two ordered sets are considered equal if they contain the same
  /// elements in the same order.
  ///
  /// - Complexity: O(`min(left.count, right.count)`)
  @inlinable
  internal static func ==(left: Self, right: Self) -> Bool {
    left.elementsEqual(right)
  }
}
