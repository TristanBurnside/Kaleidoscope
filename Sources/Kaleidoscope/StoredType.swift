//
//  StoredType.swift
//  Kaleidescope
//
//  Created by Tristan Burnside on 20/8/17.
//  Copyright © 2017 Tristan Burnside. All rights reserved.
//

import LLVM

protocol StoredType {
  var IRType: IRType? { get }
  var name: String { get }

  init?(name: String)
}

struct CustomStore: StoredType {
  // Type is currently unknown
  let IRType: IRType? = nil
  
  let name: String
  
  init?(name: String) {
    self.name = name
  }
}
