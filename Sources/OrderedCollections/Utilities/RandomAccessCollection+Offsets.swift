//===----------------------------------------------------------------------===//
//
// This source file is part of the Vapor open source project
//
// Copyright (c) 2017-2021 Vapor project authors
// Licensed under MIT
//
// See LICENSE for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
//
// This was included from Apple's Swift Collections project. The license for the
// original work is reproduced below. See NOTICES.txt for more.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

extension RandomAccessCollection {
  @inlinable
  @inline(__always)
  internal func _index(at offset: Int) -> Index {
    index(startIndex, offsetBy: offset)
  }

  @inlinable
  @inline(__always)
  internal func _offset(of index: Index) -> Int {
    distance(from: startIndex, to: index)
  }

  @inlinable
  @inline(__always)
  internal subscript(_offset offset: Int) -> Element {
    self[_index(at: offset)]
  }
}
