//
//  PrimitveStoredTypes.swift
//  Kaleidescope
//
//  Created by Tristan Burnside on 20/8/17.
//  Copyright © 2017 Tristan Burnside. All rights reserved.
//

import LLVM

struct DoubleStore: StoredType {
  var IRType: IRType? {
    return FloatType.double
  }
  let name = "Double"
}
extension DoubleStore {
  init?(name: String) {
    guard name == self.name else {
      return nil
    }
  }
  
}

struct IntStore: StoredType {
  let name = "Int"
  var IRType: IRType? {
    return IntType(width: MemoryLayout<Int>.size * 8)
  }
}
extension IntStore {
  init?(name: String) {
    guard name == self.name else {
      return nil
    }
  }
}

struct FloatStore: StoredType {
  let name = "Float"
  var IRType: IRType? {
    return FloatType.float
  }
}
extension FloatStore {
  init?(name: String) {
    guard name == self.name else {
      return nil
    }
  }
}

struct StringStore: StoredType {
  let name = "String"
  var IRType: IRType? {
    return ArrayType(elementType: IntType.int8, count: 100)
  }
}
extension StringStore {
  init?(name: String) {
    guard name == self.name else {
      return nil
    }
  }
}

struct VoidStore: StoredType {
  let name = ""
  var IRType: IRType? {
    return VoidType()
  }
}
extension VoidStore {
  init?(name: String) {
      return nil
  }
}
