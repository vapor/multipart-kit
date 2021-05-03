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

extension OrderedDictionary: CustomDebugStringConvertible {
  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    _debugDescription(typeName: _debugTypeName())
  }

  internal func _debugTypeName() -> String {
    "OrderedDictionary<\(Key.self), \(Value.self)>"
  }

  internal func _debugDescription(typeName: String) -> String {
    var result = "\(typeName)("
    if isEmpty {
      result += "[:]"
    } else {
      result += "["
      var first = true
      for (key, value) in self {
        if first {
          first = false
        } else {
          result += ", "
        }
        debugPrint(key, terminator: "", to: &result)
        result += ": "
        debugPrint(value, terminator: "", to: &result)
      }
      result += "]"
    }
    result += ")"
    return result
  }
}
