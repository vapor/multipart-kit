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

extension OrderedSet: CustomDebugStringConvertible {
  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    _debugDescription(typeName: _debugTypeName())
  }

  internal func _debugTypeName() -> String {
    "OrderedSet<\(Element.self)>"
  }

  internal func _debugDescription(typeName: String) -> String {
    var result = "\(typeName)(["
    var first = true
    for item in self {
      if first {
        first = false
      } else {
        result += ", "
      }
      debugPrint(item, terminator: "", to: &result)
    }
    result += "])"
    return result
  }
}
