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

extension OrderedDictionary {
  #if COLLECTIONS_INTERNAL_CHECKS
  @inline(never) @_effects(releasenone)
  public func _checkInvariants() {
    precondition(_keys.count == _values.count)
    _keys.__unstable._checkInvariants()
  }
  #else
  @inline(__always) @inlinable
  public func _checkInvariants() {}
  #endif // COLLECTIONS_INTERNAL_CHECKS
}
